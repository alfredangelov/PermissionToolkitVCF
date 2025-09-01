<#
.SYNOPSIS
  Backward-compatible export of roles and permissions for legacy vSphere (e.g., 5.5).

.DESCRIPTION
  Reads SourceServerHost from shared/Configuration.psd1, retrieves credentials from
  SecretManagement vault 'VCenterVault' (secret 'SourceCred'), connects with PowerCLI,
  and exports:
    - Get-VIRole       -> Roles.csv
    - Get-VIPermission -> Permissions.csv

  Designed to be conservative and compatible with older vCenter (5.x) endpoints.

.PARAMETER ConfigPath
  Path to Configuration.psd1 (defaults to shared/Configuration.psd1 under script root).

.PARAMETER VaultName
  SecretManagement vault name. Default: VCenterVault

.PARAMETER SecretName
  Secret name containing PSCredential. Default: SourceCred

.PARAMETER OutputPath
  Folder to write CSV outputs. Default: current directory.

.NOTES
  - Requires VMware.PowerCLI and Microsoft.PowerShell.SecretManagement
  - Will ignore invalid certificates and broaden TLS protocols for legacy compatibility
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'shared/Configuration.psd1'),
  [string]$VaultName = 'VCenterVault',
  [string]$SecretName = 'SourceCred',
  [string]$OutputPath = (Get-Location).Path
)

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-Err  { param([string]$Message) Write-Error $Message }

try {
  # Broaden TLS for legacy endpoints (TLS1.0/1.1/1.2)
  $sp = [Net.ServicePointManager]::SecurityProtocol
  $desired = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
  [Net.ServicePointManager]::SecurityProtocol = $sp -bor $desired
} catch {}

# Validate modules present
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
  Write-Err 'VMware.PowerCLI is not installed. Please install it and retry.'
  return 1
}
if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
  Write-Err 'Microsoft.PowerShell.SecretManagement is not installed. Please install it and retry.'
  return 1
}

# Import modules (resilient to already-loaded assemblies)
try {
  if (-not (Get-Command -Name Connect-VIServer -ErrorAction SilentlyContinue)) {
    # Prefer importing the Core module to reduce meta-module side effects
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
  }
} catch {
  # If assemblies are already loaded, the command may still be available
  if (Get-Command -Name Connect-VIServer -ErrorAction SilentlyContinue) {
    Write-Warn 'PowerCLI appears loaded already; continuing despite import error.'
  } else {
    Write-Err "Failed to import VMware.PowerCLI/Core. $_"
    return 1
  }
}

try {
  if (-not (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
  }
} catch {
  if (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue) {
    Write-Warn 'SecretManagement appears loaded already; continuing despite import error.'
  } else {
    Write-Err "Failed to import Microsoft.PowerShell.SecretManagement. $_"
    return 1
  }
}

# PowerCLI configuration for legacy SSL/cert behavior and no CEIP prompts
try {
  Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP:$false -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
} catch {}

# Load configuration
if (-not (Test-Path -Path $ConfigPath)) {
  Write-Err "Configuration file not found: $ConfigPath"
  return 1
}

try {
  $config = Import-PowerShellDataFile -Path $ConfigPath
} catch {
  Write-Err "Failed to parse configuration file: $ConfigPath. $_"
  return 1
}

$server = $config.SourceServerHost
if (-not $server) {
  Write-Err 'SourceServerHost is missing from configuration.'
  return 1
}

# Retrieve credential from SecretManagement
try {
  $null = Get-SecretVault -Name $VaultName -ErrorAction Stop
} catch {
  Write-Err "Secret vault '$VaultName' is not registered. Register it and store credentials as '$SecretName'."
  return 1
}

$cred = $null
try {
  $cred = Get-Secret -Vault $VaultName -Name $SecretName -ErrorAction Stop
} catch {
  Write-Err "Failed to retrieve secret '$SecretName' from vault '$VaultName'. $_"
  return 1
}

if ($cred -isnot [pscredential]) {
  Write-Err "Secret '$SecretName' in vault '$VaultName' is not a PSCredential."
  return 1
}

# Ensure output path exists
try { if (-not (Test-Path -Path $OutputPath)) { $null = New-Item -ItemType Directory -Path $OutputPath -Force } } catch {}

# Connect and export
$connected = $false
try {
  Write-Info "Connecting to vCenter: $server"
  $si = Connect-VIServer -Server $server -Credential $cred -ErrorAction Stop
  $connected = $true

  $rolesCsv = Join-Path -Path $OutputPath -ChildPath 'Roles.csv'
  $permsCsv = Join-Path -Path $OutputPath -ChildPath 'Permissions.csv'

  Write-Info "Exporting roles to: $rolesCsv"
  Get-VIRole | Export-Csv -Path $rolesCsv -NoTypeInformation

  Write-Info "Exporting permissions to: $permsCsv"
  Get-VIPermission | Export-Csv -Path $permsCsv -NoTypeInformation

  Write-Host "Done." -ForegroundColor Green
} catch {
  Write-Err "Export failed. $_"
  return 1
} finally {
  if ($connected) {
    try { Disconnect-VIServer -Server $server -Confirm:$false | Out-Null } catch {}
  }
}

return 0
