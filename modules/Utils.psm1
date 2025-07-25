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
    
    return $roleDescriptions[$RoleName] ?? "Custom role: $RoleName"
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
    
    return $permissionDetails[$Role] ?? @("Custom role permissions for: $Role")
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

# Export functions
Export-ModuleMember -Function @(
    'Get-EntityIdentifier',
    'Get-RoleDescription', 
    'Get-DetailedPermissions',
    'Format-TooltipContent',
    'Test-TooltipConfiguration'
)