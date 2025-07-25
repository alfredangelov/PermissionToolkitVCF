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

# --- Disconnect ---
Disconnect-VIServer -Server $viServer -Confirm:$false

Write-Host "`n🎉 Permission audit complete!"