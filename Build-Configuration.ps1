Write-Host "`n🛠️ PERMISSION TOOLKIT CONFIGURATION BUILDER" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────"

# Helper function for boolean prompts
function Read-Bool ($Prompt, $Default) {
    $defaultText = if ($Default) { "[Y/n]" } else { "[y/N]" }
    while ($true) {
        $input = Read-Host "$Prompt $defaultText"
        if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
        switch ($input.ToLower()) {
            'y' { return $true }
            'n' { return $false }
            default { Write-Host "Please enter 'y' or 'n'." -ForegroundColor Yellow }
        }
    }
}

# Prompt user for configuration values
$dryRun = Read-Bool "Enable dry run mode (no changes will be made)?" $true
$sourceHost = Read-Host "Enter source vCenter server hostname"
$exportGlobal = Read-Bool "Export global permissions?" $true
$exportNormal = Read-Bool "Export normal (object-level) permissions?" $true

# Prompt for datacenter if normal permissions are exported
if ($exportNormal) {
    $dataCenter = Read-Host "Enter the name of the datacenter in source vCenter"
}

# Build configuration hashtable
$config = @{
    DryRun                  = $dryRun
    SourceServerHost        = $sourceHost
    SourceServerUsername    = '<ToBeSetOrStoredInVault>'
    SourceServerPassword    = '<ToBeSetOrStoredInVault>'
    ExportGlobalPermissions = $exportGlobal
    ExportNormalPermissions = $exportNormal
}

if ($exportNormal) {
    $config.dataCenter = $dataCenter
}

# Output path
$configPath = Join-Path $PSScriptRoot 'shared\Configuration.psd1'

# Open file and write the opening brace
Set-Content -Path $configPath -Value "@{" -Encoding utf8

# Write each key/value pair on its own line
foreach ($item in ($config.GetEnumerator() | Sort-Object Name)) {
    Add-Content -Path $configPath -Value "    $($item.Key) = '$($item.Value)'"
}

# Write the closing brace
Add-Content -Path $configPath -Value "}"

if (Test-Path $configPath) {
    Write-Host "`n✅ Configuration saved to $configPath" -ForegroundColor Green
} else {
    Write-Host "`n❌ Failed to save configuration to $configPath" -ForegroundColor Red
}

# Register Vault (if missing)
Write-Host "`n🔐 Checking secret vault registration..."
if (-not (Get-SecretVault | Where-Object { $_.Name -eq "VCenterVault" })) {
    Write-Host "🔧 Registering vault: VCenterVault"
    Register-SecretVault -Name VCenterVault -ModuleName Microsoft.PowerShell.SecretStore
} else {
    Write-Host "✅ Secret vault already registered: VCenterVault" -ForegroundColor Green
}

# Store credentials if missing
function Test-Credential {
    param (
        [string]$Name,
        [string]$Prompt
    )
    if (-not (Get-SecretInfo | Where-Object { $_.Name -eq $Name })) {
        Write-Host "🔐 Storing credential: $Name"
        $cred = Get-Credential -Message $Prompt
        Set-Secret -Name $Name -Secret $cred
    } else {
        Write-Host "✅ Credential already stored: $Name" -ForegroundColor Green
    }
}

Test-Credential -Name "SourceCred" -Prompt "Enter source vCenter credentials"

Write-Host "`n🧾 Verifying stored secrets..."
Get-SecretInfo | Where-Object { $_.Name -in @("SourceCred") } | Format-Table Name, VaultName, LastAccessTime