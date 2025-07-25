# STEP 1: Load the configuration file
$ConfigFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'shared\Configuration.psd1'
if (-Not (Test-Path -Path $ConfigFilePath)) {
    Write-Error "`n❌ Configuration file not found at path: $ConfigFilePath" -ForegroundColor Red
    exit 1
}

$config = Import-PowerShellDataFile -Path $ConfigFilePath
if (-Not $config) {
    Write-Error "`n❌ Failed to load configuration from file: $ConfigFilePath"
    exit 1
}

# STEP 2: Validate required configuration parameters
$sourceServer = $config.SourceServerHost
$ExportNormalPermissions = $config.ExportNormalPermissions
if (-Not $sourceServer) {
    Write-Error "`n❌ Source server host is not set in the configuration." -ForegroundColor Red
    exit 1
}

# STEP 3: Test connection to the source server, is server reachable?
Write-Host "`n🌐 Validating source server: $sourceServer"
if (Test-Connection -ComputerName $sourceServer -Count 2 -Quiet) {
    Write-Host "✅ Reachable: $sourceServer"
} else {
    Write-Host "⚠️ Cannot reach $sourceServer via ICMP (ping). Check DNS, firewall, or VPN." -ForegroundColor Yellow
}

# STEP 4: Shallow login test
try {
    $srcCred = Get-Secret -Name "SourceCred"

    Write-Host "`n🔎 Attempting source vCenter login..."
    $srcSession = Connect-VIServer -Server $sourceServer -Credential $srcCred -ErrorAction Stop
    Write-Host "✅ Source login successful"

# STEP 5: We read the "dataCenter" variable from the config file, but only if ExportNormalPermissions is true
    if ($ExportNormalPermissions -and $config.ContainsKey('dataCenter')) {
        $dataCenter = $config.dataCenter
        Write-Host "📍 Data Center: $dataCenter"
    } else {
        Write-Host "ℹ️ No data center specified or export normal permissions is false." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($srcSession) {
        Disconnect-VIServer -Server $srcSession -Confirm:$false
    }
}

# FINAL CHECK
Write-Host "`n🧾 CONFIG VALIDATION PASSED"
Write-Host "Your configuration file is sound and vCenter access is verified." -ForegroundColor Green
Write-Host "`n🎯 You’re now ready to run: .\Permission-Toolkit.ps1"
