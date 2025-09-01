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
    $totalEntries = $TooltipData.Keys.Count
    $processedCount = 0
    $progressInterval = [math]::Max(1, [math]::Floor($totalEntries / 20)) # Show progress every 5%
    
    Write-Host "📊 Processing $totalEntries tooltip entries..." -ForegroundColor Cyan
    
    # Process each tooltip data entry
    foreach ($entityId in $TooltipData.Keys) {
        $processedCount++
        
        # Show progress every interval or for small datasets
        if ($processedCount % $progressInterval -eq 0 -or $totalEntries -le 50) {
            $percentComplete = [math]::Round(($processedCount / $totalEntries) * 100, 1)
            Write-Host "  🔄 Processing tooltips: $processedCount/$totalEntries ($percentComplete%)" -ForegroundColor Gray
        }
        
        $tooltipInfo = $TooltipData[$entityId]
        $tooltipContent = Format-TooltipContent -TooltipInfo $tooltipInfo
        
        # Escape special regex characters in the values
        $escapedEntityName = [regex]::Escape($tooltipInfo.EntityName)
        $escapedPrincipal = [regex]::Escape($tooltipInfo.Principal)
        $escapedRole = [regex]::Escape($tooltipInfo.Role)
        
        # Skip if this content has already been wrapped with tooltips
        if ($enhancedHtml -match "<span class=`"permission-tooltip`">$escapedEntityName<span class=`"tooltiptext`">" -or
            $enhancedHtml -match "<span class=`"permission-tooltip`">$escapedPrincipal<span class=`"tooltiptext`">" -or
            $enhancedHtml -match "<span class=`"permission-tooltip`">$escapedRole<span class=`"tooltiptext`">") {
            continue # Skip this entity as it's already processed
        }
        
        # Create patterns to match permission entries in the HTML
        $patterns = @(
            # Match table cells containing the entity name (simple and targeted)
            "(<td[^>]*>)($escapedEntityName)(</td>)",
            # Match table cells containing the principal
            "(<td[^>]*>)($escapedPrincipal)(</td>)",
            # Match table cells containing the role
            "(<td[^>]*>)($escapedRole)(</td>)"
        )
        
        $applied = $false
        foreach ($pattern in $patterns) {
            if (-not $applied -and $enhancedHtml -match $pattern) {
                $replacement = "$1<span class=`"permission-tooltip`">$2<span class=`"tooltiptext`">$tooltipContent</span></span>$3"
                # Use regex to replace only the first match
                $enhancedHtml = [regex]::Replace($enhancedHtml, $pattern, $replacement, 1)
                $applied = $true
                break
            }
        }
    }
    
    Write-Host "  ✅ Completed processing $processedCount tooltip entries" -ForegroundColor Green
    
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
    Write-Host "  🎨 Adding CSS styles..." -ForegroundColor Gray
    
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
    
    Write-Host "  📜 Adding JavaScript functionality..." -ForegroundColor Gray
    
    # Add JavaScript before closing body tag
    if ($enhancedHtml -match '(</body>)') {
        $enhancedHtml = $enhancedHtml -replace '(</body>)', "$JavaScript`n`$1"
    } else {
        # If no body tag, append JavaScript
        $enhancedHtml = "$enhancedHtml`n$JavaScript"
    }
    
    Write-Host "  ✅ Assets successfully injected" -ForegroundColor Green
    
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

function Get-SsoAnalysisHtml {
    <#
    .SYNOPSIS
        Generates HTML content for SSO external domain analysis.
    
    .PARAMETER SsoAnalysis
        SSO analysis data to convert to HTML.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SsoAnalysis
    )
    
    $ssoHtml = @"
        
        <div class="sso-section">
            <h2>🌐 SSO External Domain Analysis</h2>
"@

    # Check if SSO module is not available
    if ($SsoAnalysis.SsoModuleNotAvailable) {
        $ssoHtml += @"
            <div class="sso-error">
                <h3>⚠️ SSO Analysis Not Available</h3>
                <p>SSO cmdlets are not available in this PowerCLI environment.</p>
            </div>
            <div class="sso-stats">
                <h3>📋 Manual Alternatives</h3>
                <p><strong>To check for external domains manually:</strong></p>
                <ol>
                    <li><strong>vCenter UI Method:</strong>
                        <ul>
                            <li>Open vCenter Server UI</li>
                            <li>Navigate to: Administration → Single Sign On → Users and Groups</li>
                            <li>Check each group for members from external domains</li>
                            <li>Look for domains other than 'vsphere.local'</li>
                        </ul>
                    </li>
                    <li><strong>PowerCLI Alternative:</strong>
                        <ul>
                            <li>Use newer Identity Provider APIs: <code>Invoke-ListIdentityProviders</code></li>
                            <li>Check for external identity sources configured</li>
                        </ul>
                    </li>
                    <li><strong>REST API Method:</strong>
                        <ul>
                            <li>Use vCenter REST APIs directly for SSO data</li>
                            <li>Query: <code>/rest/com/vmware/cis/tagging</code> endpoints</li>
                        </ul>
                    </li>
                </ol>
            </div>
            <div class="sso-stats">
                <h3>🔧 Technical Details</h3>
                <p><strong>Common reasons for SSO cmdlet unavailability:</strong></p>
                <ul>
                    <li>Modern PowerCLI versions have deprecated traditional SSO cmdlets</li>
                    <li>SSO modules may not be installed or loaded</li>
                    <li>vCenter version compatibility with PowerCLI modules</li>
                    <li>Administrative privilege requirements</li>
                </ul>
            </div>
"@
        
        if ($SsoAnalysis.FallbackMessage) {
            $ssoHtml += @"
            <div class="sso-stats">
                <h3>💡 Recommended Actions</h3>
                <pre style="white-space: pre-wrap; font-family: monospace; background: rgba(255,255,255,0.1); padding: 15px; border-radius: 5px;">$($SsoAnalysis.FallbackMessage)</pre>
            </div>
"@
        }
    } else {
        # Show normal SSO analysis results
        # Show statistics
        $ssoHtml += @"
            <div class="sso-stats">
                <h3>📊 Analysis Summary</h3>
                <p><strong>Groups Scanned:</strong> $($SsoAnalysis.TotalGroupsScanned)</p>
                <p><strong>External Members Found:</strong> $($SsoAnalysis.ExternalMembers.Count)</p>
                <p><strong>External Domains Discovered:</strong> $($SsoAnalysis.ExternalDomains.Count)</p>
            </div>
"@

        # Show external domains if found
        if ($SsoAnalysis.ExternalDomains.Count -gt 0) {
            $ssoHtml += @"
            <h3>🏢 External Domains Found</h3>
            <div class="sso-domains-grid">
"@
            
            foreach ($domain in $SsoAnalysis.ExternalDomains) {
                $ssoHtml += @"
                <div class="sso-domain-card">
                    <div class="sso-domain-name">🌐 $($domain.Domain)</div>
                    <p><strong>Members:</strong> $($domain.MemberCount)</p>
                    <p><strong>Groups:</strong> $($domain.Groups.Count)</p>
                    <p><strong>Group Names:</strong> $($domain.Groups -join ', ')</p>
                </div>
"@
            }
            
            $ssoHtml += @"
            </div>
"@
        } else {
            $ssoHtml += @"
            <div class="sso-stats">
                <h3>✅ No External Domains Found</h3>
                <p>All SSO group members belong to the vsphere.local domain.</p>
            </div>
"@
        }

        # Show errors if any
        if ($SsoAnalysis.ErrorsEncountered.Count -gt 0) {
            if ($SsoAnalysis.HasInsufficientPrivileges) {
                $ssoHtml += @"
            <div class="sso-warning">
                <h3>⚠️ Privilege Warning</h3>
                <p>Some SSO groups could not be analyzed due to insufficient privileges. To get complete results, ensure you have SSO administrator access.</p>
                <p><strong>Errors encountered:</strong> $($SsoAnalysis.ErrorsEncountered.Count)</p>
            </div>
"@
            } else {
                $ssoHtml += @"
            <div class="sso-error">
                <h3>❌ Analysis Errors</h3>
                <p>Errors were encountered during SSO analysis:</p>
                <ul>
"@
                foreach ($InScriptError in $SsoAnalysis.ErrorsEncountered | Select-Object -First 5) {
                    $ssoHtml += "<li><strong>$($InScriptError.GroupName):</strong> $($InScriptError.ErrorMessage)</li>"
                }
                
                if ($SsoAnalysis.ErrorsEncountered.Count -gt 5) {
                    $ssoHtml += "<li><em>... and $($SsoAnalysis.ErrorsEncountered.Count - 5) more errors</em></li>"
                }
                
                $ssoHtml += @"
                </ul>
            </div>
"@
            }
        }
    }

    $ssoHtml += @"
        </div>
"@
    
    return $ssoHtml
}

function Export-HTMLReport {
    <#
    .SYNOPSIS
        Exports permissions to a grouped HTML report.
    
    .PARAMETER Permissions
        Permission data to export.
    
    .PARAMETER OutputPath
        Path for the output HTML file.
    
    .PARAMETER Config
        Configuration object.
    
    .PARAMETER SsoAnalysis
        Optional SSO analysis data to include in the report.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Permissions,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter()]
        [hashtable]$SsoAnalysis
    )
    
    Write-Host "📄 Generating grouped HTML report..."
    
    # Group permissions by type
    $groupResult = Group-PermissionsByType -Permissions $Permissions
    $groupedPermissions = $groupResult.Groups
    $summary = $groupResult.Summary
    
    # Start building HTML
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>vSphere Permissions Report</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f5f5f5;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background-color: white; 
            border-radius: 8px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }
        .header { 
            color: #2c3e50; 
            margin-bottom: 30px; 
            text-align: center;
            border-bottom: 3px solid #3498db;
            padding-bottom: 20px;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            color: #2c3e50;
        }
        .summary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .summary-item {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 5px;
            text-align: center;
        }
        .summary-number {
            font-size: 2em;
            font-weight: bold;
            display: block;
        }
        .group-section {
            margin-bottom: 40px;
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }
        .group-header {
            padding: 15px 20px;
            color: white;
            font-weight: bold;
            font-size: 1.2em;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .group-description {
            font-size: 0.9em;
            opacity: 0.9;
            margin-top: 5px;
        }
        .group-count {
            background: rgba(255,255,255,0.2);
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 0.9em;
        }
        .group-table {
            width: 100%;
            border-collapse: collapse;
            margin: 0;
        }
        .group-table th {
            background-color: #f8f9fa;
            color: #495057;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            border-bottom: 2px solid #dee2e6;
        }
        .group-table td {
            padding: 10px 12px;
            border-bottom: 1px solid #dee2e6;
            vertical-align: top;
        }
        .group-table tr:hover {
            background-color: #f8f9fa;
        }
        .inherited-badge {
            background-color: #ffc107;
            color: #856404;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .propagate-badge {
            background-color: #28a745;
            color: white;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .role-badge {
            background-color: #6c757d;
            color: white;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.8em;
        }
        .principal {
            font-family: 'Courier New', monospace;
            background-color: #f1f3f4;
            padding: 2px 4px;
            border-radius: 3px;
            font-size: 0.9em;
        }
        .empty-group {
            text-align: center;
            padding: 40px;
            color: #6c757d;
            font-style: italic;
        }
        .toc {
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 30px;
        }
        .toc h3 {
            margin-top: 0;
            color: #495057;
        }
        .toc-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .toc-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #dee2e6;
        }
        .toc-item:last-child {
            border-bottom: none;
        }
        .toc-link {
            text-decoration: none;
            color: #495057;
            display: flex;
            align-items: center;
        }
        .toc-link:hover {
            color: #007bff;
        }
        .toc-count {
            background-color: #007bff;
            color: white;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 0.8em;
        }
        .sso-section {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .sso-domains-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .sso-domain-card {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 5px;
        }
        .sso-domain-name {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .sso-stats {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
        .sso-error {
            background-color: #e74c3c;
            color: white;
            padding: 15px;
            border-radius: 5px;
            margin-top: 15px;
        }
        .sso-warning {
            background-color: #f39c12;
            color: white;
            padding: 15px;
            border-radius: 5px;
            margin-top: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 vSphere Permissions Report</h1>
            <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p><strong>Server:</strong> $($Config.SourceServerHost)</p>
        </div>
        
        <div class="summary">
            <h2>📊 Summary Statistics</h2>
            <div class="summary-grid">
                <div class="summary-item">
                    <span class="summary-number">$($summary.TotalPermissions)</span>
                    Total Permissions
                </div>
"@

    # Add summary for each group
    foreach ($groupName in $groupedPermissions.Keys) {
        $count = $summary.GroupCounts[$groupName]
        if ($count -gt 0) {
            $groupInfo = Get-GroupDisplayInfo -GroupName $groupName
            $htmlContent += @"
                <div class="summary-item">
                    <span class="summary-number">$count</span>
                    $($groupInfo.Icon) $($groupInfo.Title -replace ' Permissions', '')
                </div>
"@
        }
    }

    $htmlContent += @"
            </div>
        </div>
"@

    # Add SSO Analysis section if data is provided
    if ($SsoAnalysis) {
        $htmlContent += Get-SsoAnalysisHtml -SsoAnalysis $SsoAnalysis
    }
    
    $htmlContent += @"
        
        <div class="toc">
            <h3>📑 Table of Contents</h3>
            <ul class="toc-list">
"@

    # Build table of contents
    foreach ($groupName in $groupedPermissions.Keys) {
        $count = $summary.GroupCounts[$groupName]
        if ($count -gt 0) {
            $groupInfo = Get-GroupDisplayInfo -GroupName $groupName
            $htmlContent += @"
                <li class="toc-item">
                    <a href="#group-$groupName" class="toc-link">
                        $($groupInfo.Icon) $($groupInfo.Title)
                    </a>
                    <span class="toc-count">$count</span>
                </li>
"@
        }
    }

    $htmlContent += @"
            </ul>
        </div>
"@

    # Add sections for each group
    foreach ($groupName in $groupedPermissions.Keys) {
        $groupPermissions = $groupedPermissions[$groupName]
        $count = $summary.GroupCounts[$groupName]
        
        if ($count -gt 0) {
            $groupInfo = Get-GroupDisplayInfo -GroupName $groupName
            
            $htmlContent += @"
        <div class="group-section" id="group-$groupName">
            <div class="group-header" style="background-color: $($groupInfo.Color);">
                <div>
                    <div>$($groupInfo.Icon) $($groupInfo.Title)</div>
                    <div class="group-description">$($groupInfo.Description)</div>
                </div>
                <div class="group-count">$count permissions</div>
            </div>
"@

            if ($groupPermissions.Count -gt 0) {
                $htmlContent += @"
            <table class="group-table">
                <thead>
                    <tr>
                        <th>Entity</th>
                        <th>Principal</th>
                        <th>Role</th>
                        <th>Properties</th>
                    </tr>
                </thead>
                <tbody>
"@

                # Add permission rows for this group
                foreach ($permission in $groupPermissions) {
                    $inheritedBadge = if ($permission.Inherited) { '<span class="inherited-badge">INHERITED</span>' } else { '' }
                    $propagateBadge = if ($permission.Propagate) { '<span class="propagate-badge">PROPAGATE</span>' } else { '' }
                    
                    # Simple HTML encoding
                    $entityName = if ($permission.Entity) { $permission.Entity -replace '<', '&lt;' -replace '>', '&gt;' -replace '&', '&amp;' } else { 'N/A' }
                    $principalName = if ($permission.Principal) { $permission.Principal -replace '<', '&lt;' -replace '>', '&gt;' -replace '&', '&amp;' } else { 'N/A' }
                    $roleName = if ($permission.Role) { $permission.Role -replace '<', '&lt;' -replace '>', '&gt;' -replace '&', '&amp;' } else { 'N/A' }
                    
                    $htmlContent += @"
                    <tr>
                        <td>$entityName</td>
                        <td><span class="principal">$principalName</span></td>
                        <td><span class="role-badge">$roleName</span></td>
                        <td>$inheritedBadge $propagateBadge</td>
                    </tr>
"@
                }

                $htmlContent += @"
                </tbody>
            </table>
"@
            } else {
                $htmlContent += @"
            <div class="empty-group">
                No permissions found in this category
            </div>
"@
            }

            $htmlContent += @"
        </div>
"@
        }
    }

    $htmlContent += @"
    </div>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✅ Grouped HTML report saved to: $OutputPath"
    Write-Host "📊 Report contains $($summary.TotalPermissions) permissions across $($summary.GroupCounts.Keys.Where({$summary.GroupCounts[$_] -gt 0}).Count) categories"
}

# Export functions
Export-ModuleMember -Function @(
    'Convert-HtmlToTooltipEnabled',
    'Add-TooltipAssetsToHtml',
    'New-TooltipStylesheet',
    'New-TooltipJavaScript',
    'Get-SsoAnalysisHtml',
    'Export-HTMLReport'
)