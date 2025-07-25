<#
.SYNOPSIS
    Enhances HTML permission reports with interactive tooltips.

.DESCRIPTION
    Adds tooltip functionality to HTML permission reports, providing detailed information
    about permissions, roles, and objects when users hover over elements.
    
.PARAMETER InputHtmlPath
    Path to the input HTML report file
    
.PARAMETER OutputHtmlPath
    Path for the enhanced HTML report with tooltips
    
.PARAMETER PermissionData
    Raw permission data for tooltip content generation

.EXAMPLE
    .\Permission-Tooltip.ps1 -InputHtmlPath "report.html" -OutputHtmlPath "enhanced-report.html" -PermissionData $permissions
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputHtmlPath,
    
    [Parameter(Mandatory = $true)]
    [string]$OutputHtmlPath,
    
    [Parameter(Mandatory = $true)]
    [object[]]$PermissionData
)

Write-Host "`n🎯 Enhancing HTML report with tooltips..." -ForegroundColor Cyan

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

# --- Validate Input File ---
if (-not (Test-Path $InputHtmlPath)) {
    Write-Error "Input HTML file not found: $InputHtmlPath"
    exit 1
}

# --- Load and Parse HTML Content ---
Write-Host "📖 Loading HTML content from: $InputHtmlPath"
$htmlContent = Get-Content -Path $InputHtmlPath -Raw

# --- Generate Tooltip Data Structure ---
Write-Host "🔧 Generating tooltip data structure..."
$tooltipData = @{}

foreach ($permission in $PermissionData) {
    $entityId = Get-EntityIdentifier -Permission $permission
    
    $tooltipInfo = @{
        EntityName = $permission.Entity
        EntityType = $permission.EntityType
        Principal = $permission.Principal
        Role = $permission.Role
        RoleDescription = Get-RoleDescription -RoleName $permission.Role
        Inherited = $permission.Inherited
        Propagate = $permission.Propagate
        Details = @{
            CreatedDate = $permission.CreatedDate
            ModifiedDate = $permission.ModifiedDate
            Source = $permission.Source
            Permissions = Get-DetailedPermissions -Role $permission.Role
        }
    }
    
    $tooltipData[$entityId] = $tooltipInfo
}

# --- Generate Assets using Module Functions ---
Write-Host "🎨 Generating tooltip assets..."

# Get tooltip theme from config, default to Dark
$tooltipTheme = if ($config.ContainsKey('TooltipTheme')) { $config.TooltipTheme } else { 'Dark' }
$tooltipWidth = if ($config.ContainsKey('TooltipMaxWidth')) { $config.TooltipMaxWidth } else { 320 }

$tooltipCSS = New-TooltipStylesheet -Theme $tooltipTheme -MaxWidth $tooltipWidth
$tooltipJS = New-TooltipJavaScript -EnableFiltering $true -EnableKeyboard $true

# --- Process HTML Content using Module Functions ---
Write-Host "🔄 Processing HTML content and adding tooltips..."
$enhancedHtml = Convert-HtmlToTooltipEnabled -HtmlContent $htmlContent -TooltipData $tooltipData
$enhancedHtml = Add-TooltipAssetsToHtml -HtmlContent $enhancedHtml -CSS $tooltipCSS -JavaScript $tooltipJS

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