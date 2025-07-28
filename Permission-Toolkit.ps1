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

# --- Audit Permissions ---
Write-Host "`n🔎 Auditing permissions..."
$permissions = Get-Permissions -Server $viServer -Config $config

# --- Export HTML Report ---
Write-Host "`n📄 Exporting permissions report to HTML..."
$reportPath = Join-Path $PSScriptRoot "Permissions-Report.html"
Export-HTMLReport -Permissions $permissions -OutputPath $reportPath -Config $config

Write-Host "`n✅ Report generated: $reportPath" -ForegroundColor Green

# --- Optional: Enhance with Tooltips ---
if ($config.ContainsKey('EnableTooltips') -and $config.EnableTooltips -eq $true) {
    Write-Host "`n🎯 Enhancing report with interactive tooltips..." -ForegroundColor Cyan
    
    try {
        $enhancedReportPath = $reportPath -replace '\.html$', '-Enhanced.html'
        
        # Load tooltip enhancement modules if not already loaded
        $tooltipModules = @('Utils.psm1', 'Export-HTML.Report.psm1')
        foreach ($module in $tooltipModules) {
            $modulePath = Join-Path $modulesPath $module
            if (Test-Path $modulePath) {
                Import-Module $modulePath -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Load HTML content
        $htmlContent = Get-Content -Path $reportPath -Raw
        
        # Generate tooltip data
        $tooltipData = @{}
        foreach ($permission in $permissions) {
            $entityId = Get-EntityIdentifier -Permission $permission
            $tooltipInfo = @{
                EntityName = $permission.Entity
                EntityType = $permission.EntityType
                Principal = $permission.Principal
                Role = $permission.Role
                RoleDescription = Get-RoleDescription -RoleName $permission.Role
                Inherited = $permission.Inherited
                Propagate = $permission.Propagate
                Details = @{
                    CreatedDate = $permission.CreatedDate
                    ModifiedDate = $permission.ModifiedDate
                    Source = $permission.Source
                    Permissions = Get-DetailedPermissions -Role $permission.Role
                }
            }
            $tooltipData[$entityId] = $tooltipInfo
        }
        
        # Generate tooltip assets
        $tooltipTheme = if ($config.ContainsKey('TooltipTheme')) { $config.TooltipTheme } else { 'Dark' }
        $tooltipWidth = if ($config.ContainsKey('TooltipMaxWidth')) { $config.TooltipMaxWidth } else { 320 }
        
        $tooltipCSS = New-TooltipStylesheet -Theme $tooltipTheme -MaxWidth $tooltipWidth
        $tooltipJS = New-TooltipJavaScript -EnableFiltering $true -EnableKeyboard $true
        
        # Enhance HTML
        $enhancedHtml = Convert-HtmlToTooltipEnabled -HtmlContent $htmlContent -TooltipData $tooltipData
        $enhancedHtml = Add-TooltipAssetsToHtml -HtmlContent $enhancedHtml -CSS $tooltipCSS -JavaScript $tooltipJS
        
        # Save enhanced report
        $enhancedHtml | Out-File -FilePath $enhancedReportPath -Encoding UTF8
        
        Write-Host "✅ Enhanced report with tooltips: $enhancedReportPath" -ForegroundColor Green
        Write-Host "🔢 Total tooltips added: $($tooltipData.Count)" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to enhance report with tooltips: $($_.Exception.Message)"
        Write-Host "💡 You can manually enhance the report later using .\Permission-Tooltip.ps1" -ForegroundColor Yellow
    }
}

# --- Disconnect ---
Disconnect-VIServer -Server $viServer -Confirm:$false

Write-Host "`n🎉 Permission audit complete!"