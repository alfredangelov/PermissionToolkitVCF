<#
.SYNOPSIS
    Test script for Permission-Tooltip.ps1 functionality.

.DESCRIPTION
    Creates sample data and tests the tooltip enhancement functionality.
#>

# Create test data directory
$testDir = "/tmp/tooltip-test"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

# Create mock permission data
$samplePermissions = @(
    @{
        Entity = "Datacenter1"
        EntityType = "Datacenter"
        Principal = "DOMAIN\admin"
        Role = "Administrator"
        Inherited = $false
        Propagate = $true
        CreatedDate = "2024-01-15"
        ModifiedDate = "2024-01-15"
        Source = "vCenter"
    },
    @{
        Entity = "VM-WebServer01"
        EntityType = "VirtualMachine"
        Principal = "DOMAIN\webadmins"
        Role = "VirtualMachinePowerUser"
        Inherited = $true
        Propagate = $false
        CreatedDate = "2024-01-20"
        ModifiedDate = "2024-01-20"
        Source = "vCenter"
    },
    @{
        Entity = "Cluster-Production"
        EntityType = "ClusterComputeResource"
        Principal = "DOMAIN\operators"
        Role = "Read-only"
        Inherited = $false
        Propagate = $true
        CreatedDate = "2024-01-25"
        ModifiedDate = "2024-01-25"
        Source = "vCenter"
    }
)

# Create a basic HTML report to enhance
$basicHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Sample Permissions Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>vSphere Permissions Report</h1>
    <table>
        <thead>
            <tr>
                <th>Entity</th>
                <th>Principal</th>
                <th>Role</th>
                <th>Inherited</th>
                <th>Propagate</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>Datacenter1</td>
                <td>DOMAIN\admin</td>
                <td>Administrator</td>
                <td>No</td>
                <td>Yes</td>
            </tr>
            <tr>
                <td>VM-WebServer01</td>
                <td>DOMAIN\webadmins</td>
                <td>VirtualMachinePowerUser</td>
                <td>Yes</td>
                <td>No</td>
            </tr>
            <tr>
                <td>Cluster-Production</td>
                <td>DOMAIN\operators</td>
                <td>Read-only</td>
                <td>No</td>
                <td>Yes</td>
            </tr>
        </tbody>
    </table>
</body>
</html>
"@

# Save the basic HTML
$inputHtmlPath = Join-Path $testDir "basic-report.html"
$basicHtml | Out-File -FilePath $inputHtmlPath -Encoding UTF8

# Create a minimal configuration file
$testConfig = @{
    SourceServerHost = "test-vcenter.local"
    ExportNormalPermissions = $true
    ExportGlobalPermissions = $true
    TooltipTheme = "Dark"
    TooltipMaxWidth = 350
}

$configDir = Join-Path $PSScriptRoot 'shared'
$configPath = Join-Path $configDir 'Configuration.psd1'

# Create the shared directory if it doesn't exist
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Save test configuration
"@{" | Out-File -FilePath $configPath -Encoding UTF8
foreach ($key in $testConfig.Keys) {
    "    $key = '$($testConfig[$key])'" | Out-File -FilePath $configPath -Append -Encoding UTF8
}
"}" | Out-File -FilePath $configPath -Append -Encoding UTF8

Write-Host "✅ Test environment created:" -ForegroundColor Green
Write-Host "  📁 Test directory: $testDir" -ForegroundColor Cyan
Write-Host "  📄 Input HTML: $inputHtmlPath" -ForegroundColor Cyan
Write-Host "  ⚙️  Configuration: $configPath" -ForegroundColor Cyan
Write-Host "  📊 Sample permissions: $($samplePermissions.Count) entries" -ForegroundColor Cyan

# Output test parameters for running Permission-Tooltip.ps1
$outputHtmlPath = Join-Path $testDir "enhanced-report.html"

Write-Host "`n🎯 Ready to test Permission-Tooltip.ps1!" -ForegroundColor Yellow
Write-Host "Run the following command:" -ForegroundColor White
Write-Host ".\Permission-Tooltip.ps1 -InputHtmlPath '$inputHtmlPath' -OutputHtmlPath '$outputHtmlPath' -PermissionData `$samplePermissions" -ForegroundColor Gray

# Return the test data for potential use
return @{
    InputHtmlPath = $inputHtmlPath
    OutputHtmlPath = $outputHtmlPath
    PermissionData = $samplePermissions
    TestDirectory = $testDir
}