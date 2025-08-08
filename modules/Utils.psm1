<#
.SYNOPSIS
    Utility functions for the Permission Toolkit.

.DESCRIPTION
    Contains common utility functions used across the Permission Toolkit modules.
#>

function Get-EntityIdentifier {
    <#
    .SYNOPSIS
        Generates a unique identifier for a permission entity.
    
    .PARAMETER Permission
        The permission object to generate an identifier for.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Permission
    )
    
    # Create a unique identifier combining entity, principal, and role
    $identifier = "$($Permission.Entity)-$($Permission.Principal)-$($Permission.Role)".Replace(' ', '_').Replace('/', '_')
    return $identifier.ToLower()
}

function Get-RoleDescription {
    <#
    .SYNOPSIS
        Gets a description for a vSphere role.
    
    .PARAMETER RoleName
        The name of the role to get description for.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )
    
    $roleDescriptions = @{
        'Administrator' = 'Full administrative access to all vSphere objects'
        'Read-only' = 'View-only access to vSphere objects'
        'NoAccess' = 'No access - explicitly denies permissions'
        'VirtualMachinePowerUser' = 'Manage virtual machines (power operations, configuration)'
        'VirtualMachineUser' = 'Basic virtual machine interaction (console access)'
        'ResourcePoolAdministrator' = 'Full access to resource pool and child objects'
        'DatastoreConsumer' = 'Allocate space on datastores'
        'NetworkAdministrator' = 'Configure and manage network settings'
    }
    
    if ($roleDescriptions.ContainsKey($RoleName)) {
        return $roleDescriptions[$RoleName]
    } else {
        return "Custom role: $RoleName"
    }
}

function Get-DetailedPermissions {
    <#
    .SYNOPSIS
        Gets detailed permission breakdown for a role.
    
    .PARAMETER Role
        The role name to get detailed permissions for.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Role
    )
    
    $permissionDetails = @{
        'Administrator' = @(
            'All Privileges',
            'Full System Access',
            'Manage All Objects'
        )
        'Read-only' = @(
            'System.Anonymous',
            'System.Read',
            'System.View'
        )
        'NoAccess' = @(
            'No Privileges'
        )
        'VirtualMachinePowerUser' = @(
            'VirtualMachine.Interact.PowerOn',
            'VirtualMachine.Interact.PowerOff',
            'VirtualMachine.Interact.Reset',
            'VirtualMachine.Interact.Suspend',
            'VirtualMachine.Config.AddExistingDisk',
            'VirtualMachine.Config.AddNewDisk'
        )
        'VirtualMachineUser' = @(
            'VirtualMachine.Interact.ConsoleInteract',
            'VirtualMachine.Interact.DeviceConnection',
            'VirtualMachine.Interact.SetCDMedia',
            'VirtualMachine.Interact.SetFloppyMedia'
        )
        'ResourcePoolAdministrator' = @(
            'Resource.AssignVMToPool',
            'Resource.ModifyPool',
            'Resource.MovePool',
            'Resource.DeletePool'
        )
        'DatastoreConsumer' = @(
            'Datastore.AllocateSpace',
            'Datastore.Browse',
            'Datastore.FileManagement'
        )
        'NetworkAdministrator' = @(
            'Network.Assign',
            'Network.Config',
            'Network.Move',
            'Network.Delete'
        )
    }
    
    if ($permissionDetails.ContainsKey($Role)) {
        return $permissionDetails[$Role]
    } else {
        return @("Custom role permissions for: $Role")
    }
}

function Format-TooltipContent {
    <#
    .SYNOPSIS
        Formats tooltip content for display.
    
    .PARAMETER TooltipInfo
        The tooltip information object to format.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$TooltipInfo
    )
    
    $inheritedClass = if ($TooltipInfo.Inherited) { "tooltip-inherited" } else { "" }
    $propagateClass = if ($TooltipInfo.Propagate) { "tooltip-propagate" } else { "" }
    
    $permissionsList = ""
    if ($TooltipInfo.Details.Permissions) {
        $permissionsList = ($TooltipInfo.Details.Permissions | ForEach-Object {
            "<span class='tooltip-permission-item'>• $_</span>"
        }) -join "`n"
    }
    
    $tooltipHtml = @"
<div class="tooltip-section">
    <div class="tooltip-label">Entity</div>
    <div class="tooltip-value">$($TooltipInfo.EntityName) ($($TooltipInfo.EntityType))</div>
</div>
<div class="tooltip-section">
    <div class="tooltip-label">Principal</div>
    <div class="tooltip-value">$($TooltipInfo.Principal)</div>
</div>
<div class="tooltip-section">
    <div class="tooltip-label">Role</div>
    <div class="tooltip-value">$($TooltipInfo.Role)</div>
    <div class="tooltip-value" style="font-size: 11px; color: #95a5a6;">$($TooltipInfo.RoleDescription)</div>
</div>
<div class="tooltip-section">
    <div class="tooltip-label">Properties</div>
    <div class="tooltip-value $inheritedClass">Inherited: $(if ($TooltipInfo.Inherited) { 'Yes' } else { 'No' })</div>
    <div class="tooltip-value $propagateClass">Propagate: $(if ($TooltipInfo.Propagate) { 'Yes' } else { 'No' })</div>
</div>
$(if ($permissionsList) {
    "<div class='tooltip-section'><div class='tooltip-label'>Permissions</div><div class='tooltip-permissions'>$permissionsList</div></div>"
})
"@
    
    return $tooltipHtml
}

function Test-TooltipConfiguration {
    <#
    .SYNOPSIS
        Validates tooltip configuration and dependencies.
    
    .PARAMETER Config
        Configuration object to validate.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $validationResults = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    # Check for required configuration keys
    $requiredKeys = @('SourceServerHost', 'ExportNormalPermissions', 'ExportGlobalPermissions')
    foreach ($key in $requiredKeys) {
        if (-not $Config.ContainsKey($key)) {
            $validationResults.Errors += "Missing required configuration key: $key"
            $validationResults.IsValid = $false
        }
    }
    
    # Check tooltip-specific settings
    if ($Config.ContainsKey('TooltipSettings')) {
        $tooltipSettings = $Config.TooltipSettings
        if ($tooltipSettings.ContainsKey('MaxTooltipWidth') -and $tooltipSettings.MaxTooltipWidth -lt 200) {
            $validationResults.Warnings += "MaxTooltipWidth is very small (< 200px), may affect readability"
        }
    }
    
    return $validationResults
}

function Group-PermissionsByType {
    <#
    .SYNOPSIS
        Groups permissions by their object type for organized reporting.
    
    .PARAMETER Permissions
        Array of permission objects to group.
    
    .OUTPUTS
        Returns a hashtable with grouped permissions and summary statistics.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Permissions
    )
    
    $groupedPermissions = @{
        Global = @()
        VirtualMachine = @()
        VMHost = @()
        Cluster = @()
        Datastore = @()
        Folder = @()
        Datacenter = @()
        Network = @()
        ResourcePool = @()
        Other = @()
    }
    
    $summary = @{
        TotalPermissions = $Permissions.Count
        GroupCounts = @{}
    }
    
    foreach ($permission in $Permissions) {
        # Determine the group based on Source and EntityType
        $group = "Other"
        
        if ($permission.Source -eq "Global") {
            $group = "Global"
        }
        elseif ($permission.EntityType) {
            switch -Regex ($permission.EntityType) {
                '^VirtualMachine|^VM' { $group = "VirtualMachine" }
                '^HostSystem|^VMHost|^ESXi' { $group = "VMHost" }
                '^ClusterComputeResource|^Cluster' { $group = "Cluster" }
                '^Datastore' { $group = "Datastore" }
                '^Folder' { $group = "Folder" }
                '^Datacenter' { $group = "Datacenter" }
                '^Network|^DistributedVirtualSwitch|^DistributedVirtualPortgroup' { $group = "Network" }
                '^ResourcePool' { $group = "ResourcePool" }
            }
        }
        
        # Add to appropriate group
        $groupedPermissions[$group] += $permission
    }
    
    # Calculate group counts
    foreach ($groupName in $groupedPermissions.Keys) {
        $summary.GroupCounts[$groupName] = $groupedPermissions[$groupName].Count
    }
    
    return @{
        Groups = $groupedPermissions
        Summary = $summary
    }
}

function Get-GroupDisplayInfo {
    <#
    .SYNOPSIS
        Gets display information for permission groups.
    
    .PARAMETER GroupName
        The name of the permission group.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )
    
    $groupInfo = @{
        'Global' = @{
            Icon = '🌐'
            Title = 'Global Permissions'
            Description = 'Root-level permissions that apply across the entire vCenter'
            Color = '#e74c3c'
        }
        'VirtualMachine' = @{
            Icon = '🖥️'
            Title = 'Virtual Machine Permissions'
            Description = 'Permissions specific to virtual machines'
            Color = '#3498db'
        }
        'VMHost' = @{
            Icon = '🖥️'
            Title = 'ESXi Host Permissions'
            Description = 'Permissions for ESXi hosts and host systems'
            Color = '#9b59b6'
        }
        'Cluster' = @{
            Icon = '🔗'
            Title = 'Cluster Permissions'
            Description = 'Permissions for compute clusters and cluster resources'
            Color = '#e67e22'
        }
        'Datastore' = @{
            Icon = '💾'
            Title = 'Datastore Permissions'
            Description = 'Permissions for datastores and storage resources'
            Color = '#27ae60'
        }
        'Folder' = @{
            Icon = '📁'
            Title = 'Folder Permissions'
            Description = 'Permissions for organizational folders and containers'
            Color = '#f39c12'
        }
        'Datacenter' = @{
            Icon = '🏢'
            Title = 'Datacenter Permissions'
            Description = 'Permissions for datacenter objects'
            Color = '#2c3e50'
        }
        'Network' = @{
            Icon = '🌐'
            Title = 'Network Permissions'
            Description = 'Permissions for networking components and virtual switches'
            Color = '#16a085'
        }
        'ResourcePool' = @{
            Icon = '⚡'
            Title = 'Resource Pool Permissions'
            Description = 'Permissions for resource pools and resource management'
            Color = '#8e44ad'
        }
        'Other' = @{
            Icon = '📋'
            Title = 'Other Permissions'
            Description = 'Permissions for miscellaneous objects and components'
            Color = '#95a5a6'
        }
    }
    
    return $groupInfo[$GroupName]
}

function Read-ExclusionList {
    <#
    .SYNOPSIS
        Reads and parses the permission exclusion file.
    
    .PARAMETER ExclusionFilePath
        Path to the exclusion file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExclusionFilePath
    )
    
    if (-not (Test-Path $ExclusionFilePath)) {
        Write-Warning "Exclusion file not found: $ExclusionFilePath"
        return @()
    }
    
    $exclusionPatterns = @()
    $lineNumber = 0
    
    try {
        $content = Get-Content -Path $ExclusionFilePath -ErrorAction Stop
        
        foreach ($line in $content) {
            $lineNumber++
            
            # Skip empty lines and comments (lines starting with #)
            $trimmedLine = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }
            
            # Convert wildcard patterns to regex
            # Escape special regex characters except *
            $pattern = [regex]::Escape($trimmedLine)
            # Convert escaped \* back to .* for wildcard matching
            $pattern = $pattern -replace '\\\*', '.*'
            # Anchor the pattern to match the entire string
            $pattern = "^$pattern$"
            
            $exclusionPatterns += @{
                Original = $trimmedLine
                Regex = $pattern
                LineNumber = $lineNumber
            }
        }
        
        Write-Host "✅ Loaded $($exclusionPatterns.Count) exclusion patterns from: $ExclusionFilePath" -ForegroundColor Green
        
        # Log the patterns for debugging
        if ($exclusionPatterns.Count -gt 0) {
            Write-Host "🔍 Exclusion patterns loaded:" -ForegroundColor Cyan
            $exclusionPatterns | ForEach-Object {
                $wildcardIndicator = if ($_.Original -like '*\*') { ' (wildcard)' } else { '' }
                Write-Host "  Line $($_.LineNumber): $($_.Original)$wildcardIndicator" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Error "Failed to read exclusion file '$ExclusionFilePath': $($_.Exception.Message)"
        return @()
    }
    
    return $exclusionPatterns
}

function Test-PrincipalExclusion {
    <#
    .SYNOPSIS
        Tests if a principal should be excluded based on exclusion patterns.
    
    .PARAMETER Principal
        The principal name to test.
    
    .PARAMETER ExclusionPatterns
        Array of exclusion pattern objects from Read-ExclusionList.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Principal,
        
        [Parameter(Mandatory = $true)]
        [array]$ExclusionPatterns
    )
    
    foreach ($pattern in $ExclusionPatterns) {
        try {
            if ($Principal -match $pattern.Regex) {
                return @{
                    IsExcluded = $true
                    MatchedPattern = $pattern.Original
                    LineNumber = $pattern.LineNumber
                }
            }
        } catch {
            Write-Warning "Invalid regex pattern on line $($pattern.LineNumber): $($pattern.Original)"
            continue
        }
    }
    
    return @{
        IsExcluded = $false
        MatchedPattern = $null
        LineNumber = $null
    }
}

function Filter-PermissionsByExclusion {
    <#
    .SYNOPSIS
        Filters permissions based on exclusion patterns.
    
    .PARAMETER Permissions
        Array of permission objects to filter.
    
    .PARAMETER ExclusionPatterns
        Array of exclusion pattern objects.
    
    .PARAMETER ShowExclusionStats
        Whether to display exclusion statistics.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Permissions,
        
        [Parameter(Mandatory = $true)]
        [array]$ExclusionPatterns,
        
        [Parameter()]
        [bool]$ShowExclusionStats = $true
    )
    
    if ($ExclusionPatterns.Count -eq 0) {
        Write-Host "ℹ️ No exclusion patterns loaded - all permissions will be included" -ForegroundColor Yellow
        return $Permissions
    }
    
    $filteredPermissions = @()
    $excludedPermissions = @()
    $exclusionStats = @{}
    
    foreach ($permission in $Permissions) {
        $exclusionTest = Test-PrincipalExclusion -Principal $permission.Principal -ExclusionPatterns $ExclusionPatterns
        
        if ($exclusionTest.IsExcluded) {
            $excludedPermissions += $permission
            
            # Track exclusion statistics
            $pattern = $exclusionTest.MatchedPattern
            if (-not $exclusionStats.ContainsKey($pattern)) {
                $exclusionStats[$pattern] = 0
            }
            $exclusionStats[$pattern]++
        } else {
            $filteredPermissions += $permission
        }
    }
    
    if ($ShowExclusionStats) {
        Write-Host "`n🚫 Permission Exclusion Summary:" -ForegroundColor Cyan
        Write-Host "  📊 Total permissions processed: $($Permissions.Count)" -ForegroundColor White
        Write-Host "  ✅ Permissions included: $($filteredPermissions.Count)" -ForegroundColor Green
        Write-Host "  ❌ Permissions excluded: $($excludedPermissions.Count)" -ForegroundColor Red
        
        if ($exclusionStats.Count -gt 0) {
            Write-Host "`n📋 Exclusions by pattern:" -ForegroundColor Yellow
            $exclusionStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
                Write-Host "  🔸 '$($_.Key)': $($_.Value) permissions" -ForegroundColor Gray
            }
        }
    }
    
    return $filteredPermissions
}

function Get-ExternalSsoMembers {
    <#
    .SYNOPSIS
        Analyzes SSO groups to identify external domain members (non-vsphere.local).
    
    .DESCRIPTION
        Scans all SSO groups to find members from external domains.
        Excludes the default vsphere.local domain and reports external integrations.
        
        Note: This function requires SSO cmdlets that may not be available in all PowerCLI versions.
        If SSO cmdlets are not available, it will return graceful fallback information.
    
    .PARAMETER ExcludeDomain
        Domain to exclude from analysis (default: vsphere.local).
    
    .OUTPUTS
        Returns a hashtable with external domain analysis results.
    #>
    param(
        [Parameter()]
        [string]$ExcludeDomain = "vsphere.local"
    )
    
    $analysis = @{
        ExternalMembers = @()
        ExternalDomains = @()
        ErrorsEncountered = @()
        TotalGroupsScanned = 0
        HasInsufficientPrivileges = $false
        SsoModuleNotAvailable = $false
        FallbackMessage = $null
    }
    
    try {
        Write-Host "🔍 Starting SSO external domain analysis..." -ForegroundColor Cyan
        Write-Host "   Excluding domain: $ExcludeDomain" -ForegroundColor Gray
        
        # Check if SSO cmdlets are available
        $ssoGroupCommand = Get-Command "Get-SsoGroup" -ErrorAction SilentlyContinue
        $ssoGroupMemberCommand = Get-Command "Get-SsoGroupMember" -ErrorAction SilentlyContinue
        
        if (-not $ssoGroupCommand -or -not $ssoGroupMemberCommand) {
            Write-Host "⚠️ Traditional SSO cmdlets (Get-SsoGroup, Get-SsoGroupMember) are not available" -ForegroundColor Yellow
            Write-Host "   This may be due to:" -ForegroundColor Gray
            Write-Host "   • PowerCLI version compatibility" -ForegroundColor Gray
            Write-Host "   • Missing SSO modules" -ForegroundColor Gray
            Write-Host "   • vCenter version requirements" -ForegroundColor Gray
            
            $analysis.SsoModuleNotAvailable = $true
            $analysis.FallbackMessage = @"
SSO Analysis Unavailable - The traditional SSO cmdlets (Get-SsoGroup, Get-SsoGroupMember) are not available in this PowerCLI environment.

Alternative approaches:
1. Check vCenter Server UI: Administration > Single Sign On > Users and Groups
2. Use vCenter API directly for SSO queries
3. Update PowerCLI to a version that includes SSO cmdlets
4. Check if additional SSO modules need to be imported

This functionality requires access to SSO administrative APIs which may depend on:
• PowerCLI version compatibility with your vCenter version
• Specific SSO modules being available and loaded
• SSO administrative privileges on the vCenter Server
"@
            
            Write-Host "ℹ️ SSO analysis will be skipped - see HTML report for alternative approaches" -ForegroundColor Cyan
            return $analysis
        }
        
        # Get all SSO groups
        Write-Host "   Retrieving SSO groups..." -ForegroundColor Gray
        $ssoGroups = Get-SsoGroup -ErrorAction Stop
        $analysis.TotalGroupsScanned = $ssoGroups.Count
        
        Write-Host "   Found $($ssoGroups.Count) SSO groups to analyze" -ForegroundColor Gray
        
        $groupCounter = 0
        $domainsFound = @{}
        
        foreach ($group in $ssoGroups) {
            $groupCounter++
            
            # Show progress every 10 groups
            if ($groupCounter % 10 -eq 0) {
                Write-Host "   Processing group $groupCounter of $($ssoGroups.Count)..." -ForegroundColor Gray
            }
            
            try {
                # Get group members
                $members = Get-SsoGroupMember -Group $group -ErrorAction SilentlyContinue
                
                if ($members) {
                    foreach ($member in $members) {
                        # Extract domain from member name (typically DOMAIN\username or username@domain.com)
                        $memberDomain = $null
                        
                        if ($member.Name -match '^([^\\]+)\\') {
                            # Format: DOMAIN\username
                            $memberDomain = $matches[1]
                        }
                        elseif ($member.Name -match '@([^@]+)$') {
                            # Format: username@domain.com
                            $memberDomain = $matches[1]
                        }
                        elseif ($member.Domain) {
                            # Use Domain property if available
                            $memberDomain = $member.Domain
                        }
                        
                        # Check if this is an external domain
                        if ($memberDomain -and $memberDomain -ne $ExcludeDomain) {
                            $externalMember = @{
                                GroupName = $group.Name
                                GroupDescription = $group.Description
                                MemberName = $member.Name
                                MemberType = $member.Type
                                MemberDomain = $memberDomain
                                DiscoveredAt = Get-Date
                            }
                            
                            $analysis.ExternalMembers += $externalMember
                            
                            # Track unique domains
                            if (-not $domainsFound.ContainsKey($memberDomain)) {
                                $domainsFound[$memberDomain] = @{
                                    Domain = $memberDomain
                                    MemberCount = 0
                                    Groups = @()
                                }
                            }
                            
                            $domainsFound[$memberDomain].MemberCount++
                            if ($domainsFound[$memberDomain].Groups -notcontains $group.Name) {
                                $domainsFound[$memberDomain].Groups += $group.Name
                            }
                        }
                    }
                }
            }
            catch {
                $errorInfo = @{
                    GroupName = $group.Name
                    ErrorMessage = $_.Exception.Message
                    ErrorType = $_.Exception.GetType().Name
                }
                
                $analysis.ErrorsEncountered += $errorInfo
                
                # Check for insufficient privileges error
                if ($_.Exception.Message -match "insufficient|privilege|access|denied") {
                    $analysis.HasInsufficientPrivileges = $true
                }
            }
        }
        
        # Convert domains hashtable to array
        $analysis.ExternalDomains = $domainsFound.Values
        
        Write-Host "✅ SSO analysis completed" -ForegroundColor Green
        Write-Host "   Groups scanned: $($analysis.TotalGroupsScanned)" -ForegroundColor Gray
        Write-Host "   External members found: $($analysis.ExternalMembers.Count)" -ForegroundColor Gray
        Write-Host "   External domains found: $($analysis.ExternalDomains.Count)" -ForegroundColor Gray
        
        if ($analysis.ErrorsEncountered.Count -gt 0) {
            Write-Host "   Errors encountered: $($analysis.ErrorsEncountered.Count)" -ForegroundColor Yellow
            if ($analysis.HasInsufficientPrivileges) {
                Write-Host "   ⚠️ Some groups may require higher privileges to analyze" -ForegroundColor Yellow
            }
        }
        
    }
    catch {
        $analysis.ErrorsEncountered += @{
            GroupName = "SSO_SYSTEM"
            ErrorMessage = $_.Exception.Message
            ErrorType = $_.Exception.GetType().Name
        }
        
        # Check for specific SSO cmdlet not found error
        if ($_.Exception.Message -match "Get-SsoGroup.*not recognized|Get-SsoGroupMember.*not recognized") {
            $analysis.SsoModuleNotAvailable = $true
            $analysis.FallbackMessage = @"
SSO Cmdlets Not Available - The PowerCLI SSO cmdlets are not available in this environment.

This typically occurs when:
• Using newer PowerCLI versions that have deprecated traditional SSO cmdlets
• SSO modules are not installed or loaded
• vCenter version incompatibility with PowerCLI SSO modules

Alternative approaches for SSO external domain analysis:
1. Manual vCenter UI check: Administration > Single Sign On > Users and Groups
2. PowerCLI SDK methods using Identity APIs
3. Direct vCenter REST API calls for SSO data
4. Install compatible PowerCLI version with SSO module support

For automated analysis, consider updating to use the newer vCenter Identity Provider APIs available in modern PowerCLI versions.
"@
            Write-Host "❌ SSO cmdlets not available - see HTML report for manual alternatives" -ForegroundColor Red
        } else {
            Write-Host "❌ Failed to retrieve SSO groups: $($_.Exception.Message)" -ForegroundColor Red
            
            # Check if this is a privilege issue
            if ($_.Exception.Message -match "insufficient|privilege|access|denied|not authorized") {
                $analysis.HasInsufficientPrivileges = $true
                Write-Host "   This may be due to insufficient SSO administrative privileges" -ForegroundColor Yellow
                Write-Host "   Please ensure you have SSO administrator access to run this analysis" -ForegroundColor Yellow
            }
        }
    }
    
    return $analysis
}

function Update-VCenterCredentials {
    <#
    .SYNOPSIS
        Update vCenter credentials in the SecretManagement vault
    
    .DESCRIPTION
        Updates the SourceCred secret in PowerShell SecretManagement with new vCenter credentials.
        Reads the vCenter server from the current configuration.
    
    .PARAMETER Force
        Skip confirmation prompt and update credentials immediately
    
    .PARAMETER ConfigPath
        Path to configuration file (defaults to script root)
    
    .EXAMPLE
        Update-VCenterCredentials
        Interactively update credentials with confirmation
    
    .EXAMPLE
        Update-VCenterCredentials -Force
        Update credentials without confirmation
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [string]$ConfigPath
    )
    
    # Import SecretManagement if not already loaded
    try {
        if (-not (Get-Module -Name Microsoft.PowerShell.SecretManagement)) {
            Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        }
    } catch {
        Write-Error "SecretManagement module required. Install with: Install-Module Microsoft.PowerShell.SecretManagement"
        return
    }
    
    # Determine configuration path
    if (-not $ConfigPath) {
        $scriptRoot = Split-Path $PSScriptRoot -Parent
        $ConfigPath = Join-Path $scriptRoot "shared\Configuration.psd1"
    }
    
    # Load configuration
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return
    }
    
    try {
        $config = Import-PowerShellDataFile -Path $ConfigPath
        $vCenterServer = $config.SourceServerHost
    } catch {
        Write-Error "Failed to load configuration: $($_.Exception.Message)"
        return
    }
    
    if (-not $vCenterServer) {
        Write-Error "SourceServerHost not found in configuration"
        return
    }
    
    Write-Host "🔑 Updating credentials for: $vCenterServer" -ForegroundColor Cyan
    
    # Check existing credentials
    $existing = Get-SecretInfo | Where-Object { $_.Name -eq "SourceCred" }
    if ($existing) {
        try {
            $currentCred = Get-Secret -Name "SourceCred" -ErrorAction Stop
            Write-Host "Current Username: $($currentCred.UserName)" -ForegroundColor Yellow
        } catch {
            Write-Warning "Could not retrieve current credentials"
        }
    }
    
    # Confirmation (unless -Force)
    if (-not $Force) {
        $confirm = Read-Host "Update credentials for '$vCenterServer'? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            return
        }
    }
    
    # Get new credentials
    $newCred = Get-Credential -Message "Enter new credentials for $vCenterServer"
    if (-not $newCred) {
        Write-Warning "Credential entry cancelled"
        return
    }
    
    # Update secret
    try {
        Set-Secret -Name "SourceCred" -Secret $newCred -ErrorAction Stop
        Write-Host "✅ Credentials updated successfully!" -ForegroundColor Green
        
        # Verify
        $verify = Get-Secret -Name "SourceCred" -ErrorAction SilentlyContinue
        if ($verify -and $verify.UserName -eq $newCred.UserName) {
            Write-Host "✅ Update verified for user: $($verify.UserName)" -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update credentials: $($_.Exception.Message)"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-EntityIdentifier',
    'Get-RoleDescription', 
    'Get-DetailedPermissions',
    'Format-TooltipContent',
    'Test-TooltipConfiguration',
    'Group-PermissionsByType',
    'Get-GroupDisplayInfo',
    'Read-ExclusionList',
    'Test-PrincipalExclusion',
    'Filter-PermissionsByExclusion',
    'Get-ExternalSsoMembers',
    'Update-VCenterCredentials'
)