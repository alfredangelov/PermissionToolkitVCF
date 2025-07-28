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

# Export functions
Export-ModuleMember -Function @(
    'Get-EntityIdentifier',
    'Get-RoleDescription', 
    'Get-DetailedPermissions',
    'Format-TooltipContent',
    'Test-TooltipConfiguration',
    'Group-PermissionsByType',
    'Get-GroupDisplayInfo'
)