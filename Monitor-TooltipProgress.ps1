# Monitor Permission-Tooltip.ps1 Progress

Write-Host "🔍 Monitoring Permission-Tooltip.ps1 Progress" -ForegroundColor Cyan

$tooltipDataPath = ".\tooltip-data.json"
$reportPath = ".\Permissions-Report.html"
$enhancedPath = ".\Permissions-Report-Enhanced.html"

# Check if files exist
Write-Host "`n📁 File Status Check:" -ForegroundColor Yellow
Write-Host "  Tooltip Data: $(if (Test-Path $tooltipDataPath) { '✅ EXISTS' } else { '❌ MISSING' })"
Write-Host "  Base Report: $(if (Test-Path $reportPath) { '✅ EXISTS' } else { '❌ MISSING' })"
Write-Host "  Enhanced Report: $(if (Test-Path $enhancedPath) { '✅ EXISTS' } else { '❌ MISSING' })"

if (Test-Path $tooltipDataPath) {
    $tooltipData = Get-Content $tooltipDataPath -Raw | ConvertFrom-Json
    Write-Host "  📊 Tooltip entries available: $($tooltipData.TooltipData.PSObject.Properties.Count)"
}

# Monitor file changes in real-time
Write-Host "`n⏱️ Monitoring for file changes (Ctrl+C to stop)..."
$lastModified = @{}

while ($true) {
    Start-Sleep -Seconds 2
    
    # Check enhanced report file
    if (Test-Path $enhancedPath) {
        $currentModified = (Get-Item $enhancedPath).LastWriteTime
        if ($lastModified.ContainsKey('enhanced')) {
            if ($currentModified -ne $lastModified['enhanced']) {
                Write-Host "🔄 Enhanced report updated: $currentModified" -ForegroundColor Green
                $size = [math]::Round((Get-Item $enhancedPath).Length / 1KB, 2)
                Write-Host "  📏 File size: $size KB" -ForegroundColor Cyan
            }
        } else {
            Write-Host "📄 Enhanced report created: $currentModified" -ForegroundColor Green
            $size = [math]::Round((Get-Item $enhancedPath).Length / 1KB, 2)
            Write-Host "  📏 File size: $size KB" -ForegroundColor Cyan
        }
        $lastModified['enhanced'] = $currentModified
    }
    
    # Check if Permission-Tooltip.ps1 process is running
    $tooltipProcess = Get-Process | Where-Object {
        $_.ProcessName -like "*powershell*" -or $_.ProcessName -like "*pwsh*"
    } | Where-Object {
        try {
            $_.MainModule.FileName -like "*Permission-Tooltip*" -or
            $_.CommandLine -like "*Permission-Tooltip*"
        } catch {
            $false
        }
    }
    
    if (-not $tooltipProcess) {
        # Check if any PowerShell process has high CPU usage (might be our script)
        $highCpuPS = Get-Process | Where-Object {
            ($_.ProcessName -like "*powershell*" -or $_.ProcessName -like "*pwsh*") -and
            $_.CPU -gt 5
        }
        
        if ($highCpuPS) {
            Write-Host "⚡ High CPU PowerShell process detected (might be tooltip script):" -ForegroundColor Yellow
            $highCpuPS | ForEach-Object {
                Write-Host "  PID: $($_.Id), CPU: $([math]::Round($_.CPU, 2))s, Memory: $([math]::Round($_.WorkingSet64/1MB, 2))MB"
            }
        }
    }
}
