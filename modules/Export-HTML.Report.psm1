<#
.SYNOPSIS
    HTML report generation and enhancement functions for the Permission Toolkit.

.DESCRIPTION
    Contains functions for generating and enhancing HTML reports with interactive features like tooltips.
#>

function Convert-HtmlToTooltipEnabled {
    <#
    .SYNOPSIS
        Converts HTML permission entries to tooltip-enabled elements.
    
    .PARAMETER HtmlContent
        The original HTML content to enhance.
    
    .PARAMETER TooltipData
        Hashtable containing tooltip data for permissions.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$TooltipData
    )
    
    Write-Host "🔄 Converting HTML elements to tooltip-enabled format..."
    
    $enhancedHtml = $HtmlContent
    
    # Process each tooltip data entry
    foreach ($entityId in $TooltipData.Keys) {
        $tooltipInfo = $TooltipData[$entityId]
        $tooltipContent = Format-TooltipContent -TooltipInfo $tooltipInfo
        
        # Create patterns to match permission entries in the HTML
        $patterns = @(
            # Match table rows containing the entity name
            "(<tr[^>]*>.*?<td[^>]*>)($($tooltipInfo.EntityName))(</td>.*?</tr>)",
            # Match span or div elements containing the principal
            "(<span[^>]*>|<div[^>]*>)($($tooltipInfo.Principal))(</span>|</div>)",
            # Match role references
            "(<td[^>]*>|<span[^>]*>)($($tooltipInfo.Role))(</td>|</span>)"
        )
        
        foreach ($pattern in $patterns) {
            if ($enhancedHtml -match $pattern) {
                $replacement = "$1<span class=`"permission-tooltip`">$2<span class=`"tooltiptext`">$tooltipContent</span></span>$3"
                $enhancedHtml = $enhancedHtml -replace $pattern, $replacement
                break # Only apply tooltip once per entity
            }
        }
    }
    
    return $enhancedHtml
}

function Add-TooltipAssetsToHtml {
    <#
    .SYNOPSIS
        Adds CSS and JavaScript assets to HTML for tooltip functionality.
    
    .PARAMETER HtmlContent
        The HTML content to enhance.
    
    .PARAMETER CSS
        CSS styles for tooltips.
    
    .PARAMETER JavaScript
        JavaScript code for tooltip functionality.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlContent,
        
        [Parameter(Mandatory = $true)]
        [string]$CSS,
        
        [Parameter(Mandatory = $true)]
        [string]$JavaScript
    )
    
    Write-Host "💉 Injecting tooltip assets into HTML..."
    
    $enhancedHtml = $HtmlContent
    
    # Add CSS to the head section
    if ($enhancedHtml -match '(<head[^>]*>)') {
        $enhancedHtml = $enhancedHtml -replace '(<head[^>]*>)', "`$1`n$CSS"
    } elseif ($enhancedHtml -match '(<html[^>]*>)') {
        # If no head tag, add after html tag
        $enhancedHtml = $enhancedHtml -replace '(<html[^>]*>)', "`$1`n<head>$CSS</head>"
    } else {
        # If no html tag, prepend CSS
        $enhancedHtml = "$CSS`n$enhancedHtml"
    }
    
    # Add JavaScript before closing body tag
    if ($enhancedHtml -match '(</body>)') {
        $enhancedHtml = $enhancedHtml -replace '(</body>)', "$JavaScript`n`$1"
    } else {
        # If no body tag, append JavaScript
        $enhancedHtml = "$enhancedHtml`n$JavaScript"
    }
    
    return $enhancedHtml
}

function New-TooltipStylesheet {
    <#
    .SYNOPSIS
        Generates CSS stylesheet for tooltips.
    
    .PARAMETER Theme
        Visual theme for tooltips (Dark, Light, Blue).
    
    .PARAMETER MaxWidth
        Maximum width for tooltips in pixels.
    #>
    param(
        [Parameter()]
        [ValidateSet('Dark', 'Light', 'Blue')]
        [string]$Theme = 'Dark',
        
        [Parameter()]
        [int]$MaxWidth = 320
    )
    
    $themeColors = @{
        'Dark' = @{
            Background = '#2c3e50'
            Text = '#ecf0f1'
            Border = '#34495e'
            Accent = '#3498db'
            Shadow = 'rgba(0,0,0,0.15)'
        }
        'Light' = @{
            Background = '#ffffff'
            Text = '#2c3e50'
            Border = '#bdc3c7'
            Accent = '#3498db'
            Shadow = 'rgba(0,0,0,0.1)'
        }
        'Blue' = @{
            Background = '#34495e'
            Text = '#ffffff'
            Border = '#3498db'
            Accent = '#e74c3c'
            Shadow = 'rgba(52,152,219,0.2)'
        }
    }
    
    $colors = $themeColors[$Theme]
    
    return @"
<style>
/* Tooltip container */
.permission-tooltip {
    position: relative;
    display: inline-block;
    cursor: help;
    border-bottom: 1px dotted #999;
}

/* Tooltip text */
.permission-tooltip .tooltiptext {
    visibility: hidden;
    width: ${MaxWidth}px;
    background-color: $($colors.Background);
    color: $($colors.Text);
    text-align: left;
    border-radius: 8px;
    padding: 12px;
    position: absolute;
    z-index: 1000;
    bottom: 125%;
    left: 50%;
    margin-left: -$($MaxWidth / 2)px;
    opacity: 0;
    transition: opacity 0.3s, visibility 0.3s;
    box-shadow: 0 4px 12px $($colors.Shadow);
    font-size: 13px;
    line-height: 1.4;
    border: 1px solid $($colors.Border);
}

/* Tooltip arrow */
.permission-tooltip .tooltiptext::after {
    content: "";
    position: absolute;
    top: 100%;
    left: 50%;
    margin-left: -5px;
    border-width: 5px;
    border-style: solid;
    border-color: $($colors.Background) transparent transparent transparent;
}

/* Show tooltip on hover */
.permission-tooltip:hover .tooltiptext {
    visibility: visible;
    opacity: 1;
}

/* Tooltip sections */
.tooltip-section {
    margin-bottom: 8px;
    padding-bottom: 6px;
    border-bottom: 1px solid $($colors.Border);
}

.tooltip-section:last-child {
    margin-bottom: 0;
    border-bottom: none;
}

.tooltip-label {
    font-weight: bold;
    color: $($colors.Accent);
    font-size: 11px;
    text-transform: uppercase;
    margin-bottom: 2px;
}

.tooltip-value {
    color: $($colors.Text);
    margin-bottom: 4px;
}

.tooltip-inherited {
    color: #e67e22;
    font-style: italic;
}

.tooltip-propagate {
    color: #27ae60;
    font-weight: bold;
}

.tooltip-permissions {
    background-color: $($colors.Border);
    border-radius: 4px;
    padding: 6px;
    margin-top: 4px;
    font-size: 11px;
}

.tooltip-permission-item {
    display: block;
    margin-bottom: 2px;
    color: #95a5a6;
}

/* Filter controls styling */
.filter-controls {
    background-color: #f8f9fa;
    border: 1px solid #dee2e6;
    border-radius: 6px;
    padding: 15px;
    margin-bottom: 20px;
}

.filter-section h3 {
    margin: 0 0 10px 0;
    color: #495057;
    font-size: 16px;
}

.filter-section label {
    display: inline-block;
    margin-right: 15px;
    margin-bottom: 5px;
    color: #6c757d;
    cursor: pointer;
}

.filter-section input[type="checkbox"] {
    margin-right: 5px;
}
</style>
"@
}

function New-TooltipJavaScript {
    <#
    .SYNOPSIS
        Generates JavaScript code for tooltip functionality.
    
    .PARAMETER EnableFiltering
        Whether to include filtering functionality.
    
    .PARAMETER EnableKeyboard
        Whether to include keyboard accessibility.
    #>
    param(
        [Parameter()]
        [bool]$EnableFiltering = $true,
        
        [Parameter()]
        [bool]$EnableKeyboard = $true
    )
    
    $keyboardCode = if ($EnableKeyboard) {
        @"
        // Add keyboard accessibility
        tooltip.setAttribute('tabindex', '0');
        
        tooltip.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                toggleTooltip(this);
            }
        });
"@
    } else { "" }
    
    $filteringCode = if ($EnableFiltering) {
        @"
    // Add search and filter functionality
    addTooltipFiltering();
"@
    } else { "" }
    
    return @"
<script>
// Enhanced tooltip functionality
document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    initializeTooltips();
    $filteringCode
});

function initializeTooltips() {
    const tooltips = document.querySelectorAll('.permission-tooltip');
    tooltips.forEach(tooltip => {
        $keyboardCode
        
        // Mobile touch support
        tooltip.addEventListener('touchstart', function(e) {
            e.preventDefault();
            toggleTooltip(this);
        });
    });
}

function toggleTooltip(element) {
    const tooltipText = element.querySelector('.tooltiptext');
    if (tooltipText.style.visibility === 'visible') {
        tooltipText.style.visibility = 'hidden';
        tooltipText.style.opacity = '0';
    } else {
        // Hide all other tooltips first
        hideAllTooltips();
        tooltipText.style.visibility = 'visible';
        tooltipText.style.opacity = '1';
    }
}

function hideAllTooltips() {
    const allTooltipTexts = document.querySelectorAll('.tooltiptext');
    allTooltipTexts.forEach(tooltip => {
        tooltip.style.visibility = 'hidden';
        tooltip.style.opacity = '0';
    });
}

function addTooltipFiltering() {
    // Add filter controls if they don't exist
    if (!document.getElementById('tooltip-filter-controls')) {
        const filterControls = createFilterControls();
        const reportContainer = document.querySelector('body');
        reportContainer.insertBefore(filterControls, reportContainer.firstChild);
    }
}

function createFilterControls() {
    const controls = document.createElement('div');
    controls.id = 'tooltip-filter-controls';
    controls.className = 'filter-controls';
    controls.innerHTML = \`
        <div class="filter-section">
            <h3>🔍 Tooltip Filters</h3>
            <label><input type="checkbox" id="filter-inherited" checked> Show Inherited Permissions</label>
            <label><input type="checkbox" id="filter-direct" checked> Show Direct Permissions</label>
            <label><input type="checkbox" id="filter-propagate" checked> Show Propagating Permissions</label>
        </div>
    \`;
    
    // Add filter functionality
    controls.addEventListener('change', function(e) {
        applyTooltipFilters();
    });
    
    return controls;
}

function applyTooltipFilters() {
    const showInherited = document.getElementById('filter-inherited').checked;
    const showDirect = document.getElementById('filter-direct').checked;
    const showPropagate = document.getElementById('filter-propagate').checked;
    
    const tooltips = document.querySelectorAll('.permission-tooltip');
    tooltips.forEach(tooltip => {
        const tooltipText = tooltip.querySelector('.tooltiptext');
        const isInherited = tooltipText.textContent.includes('Inherited: Yes');
        const isPropagate = tooltipText.textContent.includes('Propagate: Yes');
        const isDirect = !isInherited;
        
        let shouldShow = true;
        
        if (isInherited && !showInherited) shouldShow = false;
        if (isDirect && !showDirect) shouldShow = false;
        if (isPropagate && !showPropagate) shouldShow = false;
        
        tooltip.style.display = shouldShow ? 'inline-block' : 'none';
    });
}
</script>
"@
}

function Export-HTMLReport {
    <#
    .SYNOPSIS
        Exports permissions to an HTML report (placeholder for base functionality).
    
    .PARAMETER Permissions
        Permission data to export.
    
    .PARAMETER OutputPath
        Path for the output HTML file.
    
    .PARAMETER Config
        Configuration object.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Permissions,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    Write-Host "📄 Generating basic HTML report..."
    
    # Basic HTML structure - this would be enhanced with actual permission data
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>vSphere Permissions Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .header { color: #2c3e50; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 vSphere Permissions Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Server: $($Config.SourceServerHost)</p>
    </div>
    
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
"@
    
    # Add permission rows
    foreach ($permission in $Permissions) {
        $htmlContent += @"
            <tr>
                <td>$($permission.Entity ?? 'N/A')</td>
                <td>$($permission.Principal ?? 'N/A')</td>
                <td>$($permission.Role ?? 'N/A')</td>
                <td>$(if ($permission.Inherited) { 'Yes' } else { 'No' })</td>
                <td>$(if ($permission.Propagate) { 'Yes' } else { 'No' })</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </tbody>
    </table>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✅ HTML report saved to: $OutputPath"
}

# Export functions
Export-ModuleMember -Function @(
    'Convert-HtmlToTooltipEnabled',
    'Add-TooltipAssetsToHtml',
    'New-TooltipStylesheet',
    'New-TooltipJavaScript',
    'Export-HTMLReport'
)