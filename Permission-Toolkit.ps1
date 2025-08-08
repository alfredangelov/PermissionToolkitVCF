<#
.SYNOPSIS
    Main entry point for the Permission Toolkit for vSphere.
.DESCRIPTION
    Loads configuration, imports modules, connects to vSphere, audits permissions, and exports a browsable HTML report.
#>

Write-Host "`n🔐 Permission Toolkit for vSphere" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────"

# --- Load Configuration ---
$configPath = Join-Path $PSScriptRoot 'shared\Configuration.psd1'
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file not found: $configPath"
    exit 1
}
$config = Import-PowerShellDataFile -Path $configPath

# --- Import Modules ---
$modulesPath = Join-Path $PSScriptRoot 'modules'
$moduleFiles = @(
    'Connect-VSphere.psm1',
    'Export-HTML.Report.psm1',
    'Get-Permissions.psm1',
    'Utils.psm1'
)
foreach ($mod in $moduleFiles) {
    $modPath = Join-Path $modulesPath $mod
    if (Test-Path $modPath) {
        Import-Module $modPath -Force
    } else {
        Write-Error "Module not found: $modPath"
        exit 1
    }
}

# --- Retrieve Credentials ---
try {
    $cred = Get-Secret -Name "SourceCred"
} catch {
    Write-Error "Could not retrieve vCenter credentials from SecretManagement. Please run Build-Configuration.ps1."
    exit 1
}

# --- Connect to vSphere ---
Write-Host "`n🌐 Connecting to vSphere: $($config.SourceServerHost)"
$viServer = Connect-VSphere -Server $config.SourceServerHost -Credential $cred
if (-not $viServer) {
    Write-Error "Failed to connect to vSphere server."
    exit 1
}

# --- SSO External Domain Analysis (if enabled) ---
$ssoAnalysis = $null
if ($config.ContainsKey('EnableSsoAnalysis') -and $config.EnableSsoAnalysis -eq $true) {
    Write-Host "`n🌐 Performing SSO external domain analysis..." -ForegroundColor Cyan
    $ssoAnalysis = Get-ExternalSsoMembers
    
    if ($ssoAnalysis.ExternalDomains.Count -gt 0) {
        Write-Host "🔍 Found external domains in SSO:" -ForegroundColor Yellow
        foreach ($domain in $ssoAnalysis.ExternalDomains) {
            Write-Host "  🏢 $($domain.Domain): $($domain.MemberCount) members in $($domain.Groups.Count) groups" -ForegroundColor White
        }
    } else {
        Write-Host "✅ No external domains found - all members are from vsphere.local" -ForegroundColor Green
    }
} else {
    Write-Host "ℹ️ SSO analysis disabled in configuration" -ForegroundColor Gray
}

# --- Audit Permissions ---
Write-Host "`n🔎 Auditing permissions..."
$permissions = Get-Permissions -Server $viServer -Config $config

# --- Display Permission Summary ---
Write-Host "`n📊 Permission Summary by Category:" -ForegroundColor Cyan
$groupResult = Group-PermissionsByType -Permissions $permissions
$groupedPermissions = $groupResult.Groups
$summary = $groupResult.Summary

foreach ($groupName in $groupedPermissions.Keys) {
    $count = $summary.GroupCounts[$groupName]
    if ($count -gt 0) {
        $groupInfo = Get-GroupDisplayInfo -GroupName $groupName
        Write-Host "  $($groupInfo.Icon) $($groupInfo.Title): $count permissions" -ForegroundColor White
    }
}
Write-Host "  📈 Total: $($summary.TotalPermissions) permissions across $($summary.GroupCounts.Keys.Where({$summary.GroupCounts[$_] -gt 0}).Count) categories" -ForegroundColor Yellow

# Get vCenter hostname for file naming
$vCenterHostname = $config.SourceServerHost
if ($vCenterHostname) {
    # Remove protocol and port if present, and sanitize for filename
    $hostnameForFile = $vCenterHostname -replace '^https?://', '' -replace ':\d+$', ''
    $hostnameForFile = $hostnameForFile -replace '[\\/:*?"<>|]', '-'
} else {
    $hostnameForFile = "unknown-vcenter"
}

# --- Export HTML Report ---
Write-Host "`n📄 Exporting permissions report to HTML..."
$reportPath = Join-Path $PSScriptRoot "Permissions-Report-$hostnameForFile.html"
Export-HTMLReport -Permissions $permissions -OutputPath $reportPath -Config $config -SsoAnalysis $ssoAnalysis

Write-Host "`n✅ Report generated: $reportPath" -ForegroundColor Green

# --- Export Tooltip Data for Later Enhancement ---
if ($config.ContainsKey('EnableTooltips') -and $config.EnableTooltips -eq $true) {
    Write-Host "`n💾 Exporting tooltip data for later enhancement..." -ForegroundColor Cyan
    
    try {
        # Generate tooltip data
        $tooltipData = @{}
        $roleDescriptions = @{}
        $detailedPermissions = @{}
        
        Write-Host "🔄 Processing $($permissions.Count) permissions for tooltip data..." -ForegroundColor Gray
        
        foreach ($permission in $permissions) {
            $entityId = Get-EntityIdentifier -Permission $permission
            
            # Cache role descriptions and detailed permissions to avoid duplicates
            if (-not $roleDescriptions.ContainsKey($permission.Role)) {
                $roleDescriptions[$permission.Role] = Get-RoleDescription -RoleName $permission.Role
            }
            if (-not $detailedPermissions.ContainsKey($permission.Role)) {
                $detailedPermissions[$permission.Role] = Get-DetailedPermissions -Role $permission.Role
            }
            
            $tooltipInfo = @{
                EntityName = $permission.Entity
                EntityType = $permission.EntityType
                Principal = $permission.Principal
                Role = $permission.Role
                RoleDescription = $roleDescriptions[$permission.Role]
                Inherited = $permission.Inherited
                Propagate = $permission.Propagate
                Details = @{
                    CreatedDate = $permission.CreatedDate
                    ModifiedDate = $permission.ModifiedDate
                    Source = $permission.Source
                    Permissions = $detailedPermissions[$permission.Role]
                }
            }
            $tooltipData[$entityId] = $tooltipInfo
        }
        
        # Prepare complete tooltip export data
        $exportData = @{
            Metadata = @{
                ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ToolkitVersion = "1.2.0"
                TotalPermissions = $permissions.Count
                ReportPath = $reportPath
                ConfiguredTheme = if ($config.ContainsKey('TooltipTheme')) { $config.TooltipTheme } else { 'Dark' }
                ConfiguredMaxWidth = if ($config.ContainsKey('TooltipMaxWidth')) { $config.TooltipMaxWidth } else { 320 }
            }
            TooltipData = $tooltipData
            RoleDescriptions = $roleDescriptions
            DetailedPermissions = $detailedPermissions
        }
        
        # Export to JSON file
        $tooltipDataPath = Join-Path $PSScriptRoot "tooltip-data-$hostnameForFile.json"
        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $tooltipDataPath -Encoding UTF8
        
        Write-Host "✅ Tooltip data exported: $tooltipDataPath" -ForegroundColor Green
        Write-Host "🔢 Total tooltip entries: $($tooltipData.Count)" -ForegroundColor Cyan
        Write-Host "💡 Run .\Permission-Tooltip.ps1 to enhance the HTML report with interactive tooltips" -ForegroundColor Yellow
    }
    catch {
        Write-Warning "Failed to export tooltip data: $($_.Exception.Message)"
    }
}

# --- Disconnect ---
Disconnect-VIServer -Server $viServer -Confirm:$false

Write-Host "`n🎉 Permission audit complete!"