<#
.SYNOPSIS
    Enhances HTML permission reports with interactive tooltips.

.DESCRIPTION
    Adds tooltip functionality to HTML permission reports, providing detailed information
    about permissions, roles, and objects when users hover over elements.
    Uses tooltip data exported from Permission-Toolkit.ps1 or accepts custom parameters.
    
    MEMORY OPTIMIZATION: Uses chunked processing to handle large datasets efficiently.
    Processes tooltips in configurable chunks (default 300) to prevent memory exhaustion.
    
.PARAMETER InputHtmlPath
    Path to the input HTML report file (optional if using default)
    
.PARAMETER OutputHtmlPath
    Path for the enhanced HTML report with tooltips (optional if using default)
    
.PARAMETER TooltipDataPath
    Path to the JSON file containing tooltip data (optional if using default)

.PARAMETER ChunkSize
    Override the chunk size for processing (optional, uses config default if not specified)

.EXAMPLE
    .\Permission-Tooltip.ps1
    
.EXAMPLE
    .\Permission-Tooltip.ps1 -InputHtmlPath "custom-report.html" -OutputHtmlPath "custom-enhanced.html"
    
.EXAMPLE
    .\Permission-Tooltip.ps1 -ChunkSize 150
    Uses smaller chunks for memory-constrained environments
    
.NOTES
    For large datasets (>1000 tooltips), adjust TooltipChunkSize in Configuration.psd1
    to balance processing speed vs. memory usage. Smaller chunks use less memory but
    take longer to process.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InputHtmlPath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputHtmlPath,
    
    [Parameter(Mandatory = $false)]
    [string]$TooltipDataPath,
    
    [Parameter(Mandatory = $false)]
    [int]$ChunkSize = 0  # 0 = use config default, >0 = override config
)

Write-Host "`n🎯 Enhancing HTML report with tooltips..." -ForegroundColor Cyan

# --- Load Configuration ---
$configPath = Join-Path $PSScriptRoot 'shared\Configuration.psd1'
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file not found: $configPath"
    exit 1
}
$config = Import-PowerShellDataFile -Path $configPath

# Get vCenter hostname for file naming
$vCenterHostname = $config.SourceServerHost
if ($vCenterHostname) {
    # Remove protocol and port if present, and sanitize for filename
    $hostnameForFile = $vCenterHostname -replace '^https?://', '' -replace ':\d+$', ''
    $hostnameForFile = $hostnameForFile -replace '[\\/:*?"<>|]', '-'
} else {
    $hostnameForFile = "unknown-vcenter"
}

# --- Update Default Paths with Hostname ---
if (-not $InputHtmlPath) {
    $InputHtmlPath = Join-Path $PSScriptRoot "Permissions-Report-$hostnameForFile.html"
}
if (-not $OutputHtmlPath) {
    $OutputHtmlPath = Join-Path $PSScriptRoot "Permissions-Report-$hostnameForFile-Enhanced.html"
}
if (-not $TooltipDataPath) {
    $TooltipDataPath = Join-Path $PSScriptRoot "tooltip-data-$hostnameForFile.json"
}

# --- Validate Input Files ---
if (-not (Test-Path $InputHtmlPath)) {
    Write-Error "Input HTML file not found: $InputHtmlPath"
    Write-Host "💡 Run .\Permission-Toolkit.ps1 first to generate the base report" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $TooltipDataPath)) {
    Write-Error "Tooltip data file not found: $TooltipDataPath"
    Write-Host "💡 Run .\Permission-Toolkit.ps1 with EnableTooltips=true in Configuration.psd1" -ForegroundColor Yellow
    exit 1
}

# --- Import Required Modules ---
$modulesPath = Join-Path $PSScriptRoot 'modules'
$requiredModules = @('Utils.psm1', 'Export-HTML.Report.psm1')

foreach ($module in $requiredModules) {
    $modulePath = Join-Path $modulesPath $module
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host "✅ Imported module: $module" -ForegroundColor Green
    } else {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }
}

# --- Validate Configuration for Tooltip Features ---
Write-Host "🔍 Validating tooltip configuration..."
$validationResult = Test-TooltipConfiguration -Config $config
if (-not $validationResult.IsValid) {
    Write-Error "Configuration validation failed:"
    $validationResult.Errors | ForEach-Object { Write-Error "  - $_" }
    exit 1
}
if ($validationResult.Warnings.Count -gt 0) {
    Write-Warning "Configuration warnings:"
    $validationResult.Warnings | ForEach-Object { Write-Warning "  - $_" }
}

# --- Load Tooltip Data from JSON ---
Write-Host "📖 Loading tooltip data from: $TooltipDataPath"
try {
    $exportedData = Get-Content -Path $TooltipDataPath -Raw | ConvertFrom-Json
    $tooltipData = @{}
    
    # Convert PSCustomObject back to hashtable for easier processing
    $exportedData.TooltipData.PSObject.Properties | ForEach-Object {
        $key = $_.Name
        $value = $_.Value
        
        # Convert PSCustomObject to hashtable recursively
        $hashtableValue = @{}
        $value.PSObject.Properties | ForEach-Object {
            $propName = $_.Name
            $propValue = $_.Value
            
            # Handle nested Details object
            if ($propName -eq 'Details' -and $propValue -is [PSCustomObject]) {
                $detailsHash = @{}
                $propValue.PSObject.Properties | ForEach-Object {
                    $detailsHash[$_.Name] = $_.Value
                }
                $hashtableValue[$propName] = $detailsHash
            } else {
                $hashtableValue[$propName] = $propValue
            }
        }
        
        $tooltipData[$key] = $hashtableValue
    }
    
    Write-Host "✅ Loaded $($tooltipData.Count) tooltip entries" -ForegroundColor Green
    Write-Host "📊 Data exported on: $($exportedData.Metadata.ExportDate)" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to load tooltip data: $($_.Exception.Message)"
    exit 1
}

# --- Load and Parse HTML Content ---
Write-Host "📖 Loading HTML content from: $InputHtmlPath"
$htmlContent = Get-Content -Path $InputHtmlPath -Raw

# --- Generate Assets using Module Functions ---
Write-Host "🎨 Generating tooltip assets..."

# Get tooltip theme from config or use exported metadata
$tooltipTheme = if ($config.ContainsKey('TooltipTheme')) { 
    $config.TooltipTheme 
} elseif ($exportedData.Metadata.ConfiguredTheme) {
    $exportedData.Metadata.ConfiguredTheme
} else { 
    'Dark' 
}

$tooltipWidth = if ($config.ContainsKey('TooltipMaxWidth')) { 
    $config.TooltipMaxWidth 
} elseif ($exportedData.Metadata.ConfiguredMaxWidth) {
    $exportedData.Metadata.ConfiguredMaxWidth
} else { 
    320 
}

$tooltipCSS = New-TooltipStylesheet -Theme $tooltipTheme -MaxWidth $tooltipWidth
$tooltipJS = New-TooltipJavaScript -EnableFiltering $true -EnableKeyboard $true

# --- Process HTML Content using Chunked Processing ---
Write-Host "🔄 Processing HTML content and adding tooltips..."
Write-Host "📊 Total permissions to process: $($tooltipData.Count)" -ForegroundColor Cyan

$progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

# Configuration for chunked processing
$chunkSize = if ($ChunkSize -gt 0) {
    Write-Host "🔧 Using command-line chunk size override: $ChunkSize" -ForegroundColor Yellow
    $ChunkSize
} elseif ($config.ContainsKey('TooltipChunkSize')) { 
    $config.TooltipChunkSize 
} else { 
    300  # Default safe chunk size
}

Write-Host "🧩 Using chunked processing with chunks of $chunkSize tooltips" -ForegroundColor Yellow
Write-Host "  ⏳ This approach conserves memory for large datasets..." -ForegroundColor Gray

# Since we can't modify the module function directly, we'll monitor file size changes
$originalHtmlSize = $htmlContent.Length
Write-Host "  📏 Original HTML size: $([math]::Round($originalHtmlSize/1KB, 2)) KB" -ForegroundColor Gray

# Initialize chunked processing
$enhancedHtml = $htmlContent
$tooltipKeys = $tooltipData.Keys | Sort-Object  # Sort for consistent processing
$totalTooltips = $tooltipKeys.Count
$totalChunks = [math]::Ceiling($totalTooltips / $chunkSize)
$processedCount = 0

Write-Host "  📦 Processing $totalTooltips tooltips in $totalChunks chunks of $chunkSize each" -ForegroundColor Cyan

# Process tooltips in chunks
for ($chunkIndex = 0; $chunkIndex -lt $totalChunks; $chunkIndex++) {
    $startIndex = $chunkIndex * $chunkSize
    $endIndex = [math]::Min($startIndex + $chunkSize - 1, $totalTooltips - 1)
    $currentChunk = $tooltipKeys[$startIndex..$endIndex]
    
    Write-Host "  🔄 Processing chunk $($chunkIndex + 1)/$totalChunks (tooltips $($startIndex + 1)-$($endIndex + 1))" -ForegroundColor Gray
    
    # Monitor HTML size before processing this chunk
    $htmlSizeBeforeChunk = $enhancedHtml.Length
    
    # Create hashtable for current chunk
    $chunkTooltipData = @{}
    foreach ($key in $currentChunk) {
        $chunkTooltipData[$key] = $tooltipData[$key]
    }
    
    # Process chunk using existing module function
    $enhancedHtml = Convert-HtmlToTooltipEnabled -HtmlContent $enhancedHtml -TooltipData $chunkTooltipData
    
    # Check for excessive HTML size growth (intelligent thresholds based on file size)
    $htmlSizeAfterChunk = $enhancedHtml.Length
    $chunkGrowthRatio = if ($htmlSizeBeforeChunk -gt 0) { $htmlSizeAfterChunk / $htmlSizeBeforeChunk } else { 1 }
    
    # Dynamic threshold: smaller files can have higher growth ratios due to CSS/JS overhead
    # Large files (>1MB) should have lower growth ratios to detect actual problems
    $sizeThresholdMB = $htmlSizeBeforeChunk / 1MB
    $maxGrowthRatio = if ($sizeThresholdMB -lt 0.5) { 
        5.0   # Small files (<500KB): Allow up to 5x growth (normal for tooltip enhancement)
    } elseif ($sizeThresholdMB -lt 2.0) { 
        3.0   # Medium files (500KB-2MB): Allow up to 3x growth
    } else { 
        2.0   # Large files (>2MB): Allow up to 2x growth
    }
    
    if ($chunkGrowthRatio -gt $maxGrowthRatio) {
        Write-Warning "⚠️  Excessive HTML growth detected in chunk $($chunkIndex + 1)!"
        Write-Warning "   Size before: $([math]::Round($htmlSizeBeforeChunk/1KB, 2)) KB"
        Write-Warning "   Size after: $([math]::Round($htmlSizeAfterChunk/1KB, 2)) KB"
        Write-Warning "   Growth ratio: $([math]::Round($chunkGrowthRatio, 2))x (threshold: $([math]::Round($maxGrowthRatio, 1))x)"
        Write-Warning "   This may indicate duplicate tooltip processing. Aborting to prevent memory exhaustion."
        
        # Save current progress before aborting
        $emergencyPath = $OutputHtmlPath -replace '\.html$', "-emergency-save-chunk$($chunkIndex).html"
        $enhancedHtml | Out-File -FilePath $emergencyPath -Encoding UTF8
        Write-Host "🚨 Emergency save created: $emergencyPath" -ForegroundColor Red
        
        Write-Error "Processing aborted due to excessive HTML growth. Check module regex patterns for duplicates."
        exit 1
    }
    
    # Provide informational feedback about growth (especially for smaller files)
    if ($chunkGrowthRatio -gt 2.0 -and $sizeThresholdMB -lt 0.5) {
        Write-Host "    ℹ️  HTML size growth: $([math]::Round($chunkGrowthRatio, 2))x (normal for small files when adding tooltips)" -ForegroundColor Cyan
    } elseif ($chunkGrowthRatio -gt 1.5) {
        Write-Host "    📈 HTML size growth: $([math]::Round($chunkGrowthRatio, 2))x" -ForegroundColor Gray
    }
    
    $processedCount += $currentChunk.Count
    $percentComplete = [math]::Round(($processedCount / $totalTooltips) * 100, 1)
    
    # Memory cleanup after each chunk
    $chunkTooltipData.Clear()
    $chunkTooltipData = $null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "    ✅ Chunk $($chunkIndex + 1) completed - $processedCount/$totalTooltips tooltips processed ($percentComplete%)" -ForegroundColor Green
    
    # Optional: Save intermediate progress every 5 chunks or if requested
    if (($chunkIndex + 1) % 5 -eq 0 -or $chunkIndex -eq ($totalChunks - 1)) {
        $currentSize = $enhancedHtml.Length
        Write-Host "    💾 Current HTML size: $([math]::Round($currentSize/1KB, 2)) KB" -ForegroundColor Cyan
        
        # Optional backup save (uncomment if needed for large datasets)
        $backupPath = $OutputHtmlPath -replace '\.html$', "-backup-chunk$($chunkIndex + 1).html"
        $enhancedHtml | Out-File -FilePath $backupPath -Encoding UTF8
        Write-Host "    💾 Backup saved: $backupPath" -ForegroundColor Gray
    }
}

$conversionTime = $progressTimer.Elapsed.TotalSeconds
Write-Host "  ✅ Chunked HTML conversion completed in $([math]::Round($conversionTime, 2)) seconds" -ForegroundColor Green

$enhancedHtmlSize = $enhancedHtml.Length
Write-Host "  📏 Enhanced HTML size: $([math]::Round($enhancedHtmlSize/1KB, 2)) KB (+$([math]::Round(($enhancedHtmlSize-$originalHtmlSize)/1KB, 2)) KB)" -ForegroundColor Cyan

Write-Host "💉 Injecting tooltip assets (CSS/JavaScript)..." -ForegroundColor Yellow
$enhancedHtml = Add-TooltipAssetsToHtml -HtmlContent $enhancedHtml -CSS $tooltipCSS -JavaScript $tooltipJS

$finalHtmlSize = $enhancedHtml.Length
$totalTime = $progressTimer.Elapsed.TotalSeconds
$progressTimer.Stop()

Write-Host "  ✅ Asset injection completed in $([math]::Round($totalTime - $conversionTime, 2)) seconds" -ForegroundColor Green
Write-Host "  📏 Final HTML size: $([math]::Round($finalHtmlSize/1KB, 2)) KB" -ForegroundColor Cyan
Write-Host "🎯 Chunked tooltip processing completed in $([math]::Round($totalTime, 2)) seconds total" -ForegroundColor Green
Write-Host "  📈 Processing rate: $([math]::Round($tooltipData.Count / $totalTime, 0)) tooltips/second" -ForegroundColor Yellow
Write-Host "  🧩 Used $totalChunks chunks of $chunkSize tooltips each for memory efficiency" -ForegroundColor Cyan

# --- Export Enhanced HTML ---
Write-Host "💾 Saving enhanced HTML report..."
$enhancedHtml | Out-File -FilePath $OutputHtmlPath -Encoding UTF8

# --- Generate Summary Report ---
Write-Host "📊 Generating tooltip enhancement summary..."
$summary = @{
    InputFile = $InputHtmlPath
    OutputFile = $OutputHtmlPath
    TooltipsAdded = $tooltipData.Count
    ChunkedProcessing = @{
        ChunkSize = $chunkSize
        TotalChunks = $totalChunks
        ProcessingTime = [math]::Round($totalTime, 2)
        ProcessingRate = [math]::Round($tooltipData.Count / $totalTime, 0)
    }
    EnhancementDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Features = @(
        "Interactive hover tooltips",
        "Keyboard accessibility",
        "Mobile touch support", 
        "Filter controls",
        "Detailed permission information",
        "Memory-efficient chunked processing"
    )
}

Write-Host "`n✅ Tooltip enhancement complete!" -ForegroundColor Green
Write-Host "📁 Enhanced report saved to: $OutputHtmlPath" -ForegroundColor Yellow
Write-Host "🔢 Total tooltips added: $($summary.TooltipsAdded)" -ForegroundColor Cyan

# Export summary for reporting
$summaryPath = $OutputHtmlPath -replace '\.html$', '-tooltip-summary.json'
$summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "📋 Enhancement summary saved to: $summaryPath" -ForegroundColor Green