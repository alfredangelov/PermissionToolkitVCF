<#
.SYNOPSIS
    Enhances HTML permission reports with interactive tooltips.

.DESCRIPTION
    Adds tooltip functionality to HTML permission reports, providing detailed information
    about permissions, roles, and objects when users hover over elements.
    Uses tooltip data exported from Permission-Toolkit.ps1 or accepts custom parameters.
    
.PARAMETER InputHtmlPath
    Path to the input HTML report file (optional if using default)
    
.PARAMETER OutputHtmlPath
    Path for the enhanced HTML report with tooltips (optional if using default)
    
.PARAMETER TooltipDataPath
    Path to the JSON file containing tooltip data (optional if using default)

.EXAMPLE
    .\Permission-Tooltip.ps1
    
.EXAMPLE
    .\Permission-Tooltip.ps1 -InputHtmlPath "custom-report.html" -OutputHtmlPath "custom-enhanced.html"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InputHtmlPath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputHtmlPath,
    
    [Parameter(Mandatory = $false)]
    [string]$TooltipDataPath
)

Write-Host "`n🎯 Enhancing HTML report with tooltips..." -ForegroundColor Cyan

# --- Set Default Paths ---
if (-not $InputHtmlPath) {
    $InputHtmlPath = Join-Path $PSScriptRoot "Permissions-Report.html"
}
if (-not $OutputHtmlPath) {
    $OutputHtmlPath = Join-Path $PSScriptRoot "Permissions-Report-Enhanced.html"
}
if (-not $TooltipDataPath) {
    $TooltipDataPath = Join-Path $PSScriptRoot "tooltip-data.json"
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

# --- Load Configuration ---
$configPath = Join-Path $PSScriptRoot 'shared\Configuration.psd1'
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file not found: $configPath"
    exit 1
}
$config = Import-PowerShellDataFile -Path $configPath

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

# --- Process HTML Content using Module Functions ---
Write-Host "🔄 Processing HTML content and adding tooltips..."
Write-Host "📊 Total permissions to process: $($tooltipData.Count)" -ForegroundColor Cyan

$progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

# Add progress reporting to the conversion function
Write-Host "🔄 Converting HTML elements to tooltip-enabled format..." -ForegroundColor Yellow
Write-Host "  ⏳ This may take several minutes for large datasets..." -ForegroundColor Gray

# Since we can't modify the module function directly, we'll monitor file size changes
$originalHtmlSize = $htmlContent.Length
Write-Host "  📏 Original HTML size: $([math]::Round($originalHtmlSize/1KB, 2)) KB" -ForegroundColor Gray

$enhancedHtml = Convert-HtmlToTooltipEnabled -HtmlContent $htmlContent -TooltipData $tooltipData

$conversionTime = $progressTimer.Elapsed.TotalSeconds
Write-Host "  ✅ HTML conversion completed in $([math]::Round($conversionTime, 2)) seconds" -ForegroundColor Green

$enhancedHtmlSize = $enhancedHtml.Length
Write-Host "  📏 Enhanced HTML size: $([math]::Round($enhancedHtmlSize/1KB, 2)) KB (+$([math]::Round(($enhancedHtmlSize-$originalHtmlSize)/1KB, 2)) KB)" -ForegroundColor Cyan

Write-Host "💉 Injecting tooltip assets (CSS/JavaScript)..." -ForegroundColor Yellow
$enhancedHtml = Add-TooltipAssetsToHtml -HtmlContent $enhancedHtml -CSS $tooltipCSS -JavaScript $tooltipJS

$finalHtmlSize = $enhancedHtml.Length
$totalTime = $progressTimer.Elapsed.TotalSeconds
$progressTimer.Stop()

Write-Host "  ✅ Asset injection completed in $([math]::Round($totalTime - $conversionTime, 2)) seconds" -ForegroundColor Green
Write-Host "  📏 Final HTML size: $([math]::Round($finalHtmlSize/1KB, 2)) KB" -ForegroundColor Cyan
Write-Host "🎯 Tooltip processing completed in $([math]::Round($totalTime, 2)) seconds total" -ForegroundColor Green
Write-Host "  📈 Processing rate: $([math]::Round($tooltipData.Count / $totalTime, 0)) tooltips/second" -ForegroundColor Yellow

# --- Export Enhanced HTML ---
Write-Host "💾 Saving enhanced HTML report..."
$enhancedHtml | Out-File -FilePath $OutputHtmlPath -Encoding UTF8

# --- Generate Summary Report ---
Write-Host "📊 Generating tooltip enhancement summary..."
$summary = @{
    InputFile = $InputHtmlPath
    OutputFile = $OutputHtmlPath
    TooltipsAdded = $tooltipData.Count
    EnhancementDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Features = @(
        "Interactive hover tooltips",
        "Keyboard accessibility",
        "Mobile touch support", 
        "Filter controls",
        "Detailed permission information"
    )
}

Write-Host "`n✅ Tooltip enhancement complete!" -ForegroundColor Green
Write-Host "📁 Enhanced report saved to: $OutputHtmlPath" -ForegroundColor Yellow
Write-Host "🔢 Total tooltips added: $($summary.TooltipsAdded)" -ForegroundColor Cyan

# Export summary for reporting
$summaryPath = $OutputHtmlPath -replace '\.html$', '-tooltip-summary.json'
$summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding UTF8

Write-Host "📋 Enhancement summary saved to: $summaryPath" -ForegroundColor Green