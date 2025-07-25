Write-Host "`n🛠️ PERMISSION TOOLKIT SETUP SCRIPT" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────"

# Minimum PowerShell version required
$minPSVersion = [Version]"7.5"

# Check PowerShell version
Write-Host "`n🔎 Checking PowerShell version..."
if ($PSVersionTable.PSVersion -lt $minPSVersion) {
    Write-Host "❌ PowerShell version $($PSVersionTable.PSVersion) is below required $minPSVersion" -ForegroundColor Red
    Write-Host "Please install PowerShell 7.5+ from https://github.com/PowerShell/PowerShell"
    return
} else {
    Write-Host "✅ PowerShell version OK: $($PSVersionTable.PSVersion)"
}

# Check required files
$requiredFiles = @(
    ".\modules\Connect-VSphere.psm1",
    ".\modules\Export-HTML.Report.psm1",
    ".\modules\Get-Permissions.psm1",
    ".\modules\Utils.psm1",
    ".\shared\Configuration.psd1",
    ".\Build-Configuration.ps1",
    ".\Validate-Configuration.ps1",
    ".\Permission-Toolkit.ps1"
)

Write-Host "`n📂 Verifying toolkit files..."
$missing = $requiredFiles | Where-Object { -not (Test-Path $_) }
if ($missing.Count -gt 0) {
    Write-Host "❌ Missing files: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Please clone or restore these from the toolkit repo."
    return
} else {
    Write-Host "✅ All core files present."
}

# Required modules
$modules = @(
    "VMware.PowerCLI",
    "VCF.PowerCLI",
    "Microsoft.PowerShell.SecretManagement",
    "Microsoft.PowerShell.SecretStore"
)

Write-Host "`n📦 Checking required PowerShell modules..."
foreach ($m in $modules) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "📦 Installing: $m"
        Install-Module $m -Scope CurrentUser -SkipPublisherCheck -AllowClobber
    } else {
        Write-Host "✅ Module already installed: $m"
    }
}

Write-Host "`n🎯 Toolkit environment ready."
Write-Host "You're now set to build the configuration, run .\Build-Configuration.ps1" -ForegroundColor Green
