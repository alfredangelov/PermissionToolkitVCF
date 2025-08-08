#Requires -Version 5.1
<#
.SYNOPSIS
    Update vCenter credentials in the SecretManagement vault

.DESCRIPTION
    This script updates the vCenter server credentials stored in the PowerShell SecretManagement
    vault. It reads the vCenter server from Configuration.psd1 and prompts for new credentials
    to replace the existing "SourceCred" secret.

.PARAMETER Force
    Force update credentials without confirmation prompt

.EXAMPLE
    .\Update-Credentials.ps1
    Interactively update credentials with confirmation

.EXAMPLE
    .\Update-Credentials.ps1 -Force
    Update credentials without confirmation prompt

.NOTES
    Author: Permission Toolkit
    Version: 1.0
    Dependencies: Microsoft.PowerShell.SecretManagement
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Script banner
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔑 vCenter Credential Update Utility" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Check for required modules
try {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
    Write-Host "✅ SecretManagement module loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ SecretManagement module not found" -ForegroundColor Red
    Write-Host "💡 Install with: Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
    exit 1
}

# Load configuration
$configPath = Join-Path $PSScriptRoot "shared\Configuration.psd1"
if (-not (Test-Path $configPath)) {
    Write-Host "❌ Configuration file not found: $configPath" -ForegroundColor Red
    Write-Host "💡 Run Build-Configuration.ps1 to create configuration" -ForegroundColor Yellow
    exit 1
}

try {
    $config = Import-PowerShellDataFile -Path $configPath
    Write-Host "✅ Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get vCenter server from configuration
$vCenterServer = $config.SourceServerHost
if (-not $vCenterServer) {
    Write-Host "❌ SourceServerHost not found in configuration" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 Current Configuration:" -ForegroundColor Yellow
Write-Host "   vCenter Server: $vCenterServer" -ForegroundColor White
Write-Host "   vCenter Version: $($config.vCenterVersion)" -ForegroundColor White

# Check if SourceCred secret exists
$existingSecret = Get-SecretInfo | Where-Object { $_.Name -eq "SourceCred" }
if ($existingSecret) {
    Write-Host "✅ Current SourceCred secret found in vault: $($existingSecret.VaultName)" -ForegroundColor Green
    
    # Try to retrieve and display current username (without password)
    try {
        $currentCred = Get-Secret -Name "SourceCred" -ErrorAction Stop
        Write-Host "   Current Username: $($currentCred.UserName)" -ForegroundColor White
    } catch {
        Write-Host "⚠️  Could not retrieve current credentials: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️  No existing SourceCred secret found" -ForegroundColor Yellow
}

# Confirmation prompt (unless -Force is used)
if (-not $Force) {
    Write-Host "`n❓ Do you want to update the credentials for '$vCenterServer'?" -ForegroundColor Yellow
    $choice = Read-Host "Enter 'y' to continue, any other key to cancel"
    if ($choice -ne 'y' -and $choice -ne 'Y') {
        Write-Host "❌ Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Prompt for new credentials
Write-Host "`n🔑 Enter new credentials for vCenter server: $vCenterServer" -ForegroundColor Cyan
$newCredential = Get-Credential -Message "Enter vCenter credentials for $vCenterServer"

if (-not $newCredential) {
    Write-Host "❌ Credential entry cancelled" -ForegroundColor Red
    exit 1
}

# Validate credential format
if (-not $newCredential.UserName -or $newCredential.UserName.Trim() -eq "") {
    Write-Host "❌ Invalid username provided" -ForegroundColor Red
    exit 1
}

# Store/update the credential
try {
    Write-Host "🔄 Updating credential in SecretManagement vault..." -ForegroundColor Yellow
    Set-Secret -Name "SourceCred" -Secret $newCredential -ErrorAction Stop
    Write-Host "✅ Credential updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to update credential: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verification
Write-Host "`n🧾 VERIFICATION" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────"

try {
    $updatedSecret = Get-SecretInfo | Where-Object { $_.Name -eq "SourceCred" }
    if ($updatedSecret) {
        Write-Host "✅ Secret verified in vault: $($updatedSecret.VaultName)" -ForegroundColor Green
        
        # Test retrieval
        $testCred = Get-Secret -Name "SourceCred" -ErrorAction Stop
        Write-Host "✅ New username confirmed: $($testCred.UserName)" -ForegroundColor Green
        
        # Display secret info
        Write-Host "`n📋 Secret Information:"
        $updatedSecret | Format-Table Name, VaultName, @{Name="LastAccessed";Expression={$_.LastAccessTime}} -AutoSize
    } else {
        Write-Host "❌ Could not verify updated secret" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error during verification: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 CREDENTIAL UPDATE COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Credentials updated for: $vCenterServer" -ForegroundColor Green
Write-Host "✅ Ready to run Permission-Toolkit.ps1" -ForegroundColor Green
Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Test connection: .\Validate-Configuration.ps1" -ForegroundColor White
Write-Host "   2. Run analysis: .\Permission-Toolkit.ps1" -ForegroundColor White
