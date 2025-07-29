function Get-Permissions {
    param(
        [Parameter(Mandatory = $true)]
        $Server,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $allPermissions = @()
    
    try {
        Write-Host "Starting permission audit..." -ForegroundColor Cyan
        
        # Get global permissions if enabled
        if ($Config.ExportGlobalPermissions -eq 'true' -or $Config.ExportGlobalPermissions -eq $true) {
            Write-Host "  Retrieving global permissions..." -ForegroundColor Yellow
            $globalPermissions = Get-GlobalPermissions -Server $Server
            $allPermissions += $globalPermissions
            Write-Host "  Found $($globalPermissions.Count) global permissions" -ForegroundColor Green
        }
        
        # Get object-level permissions if enabled
        if ($Config.ExportNormalPermissions -eq 'true' -or $Config.ExportNormalPermissions -eq $true) {
            Write-Host "  Retrieving object-level permissions..." -ForegroundColor Yellow
            
            $datacenterName = $Config.dataCenter
            if ($datacenterName) {
                $objectPermissions = Get-ObjectPermissions -Server $Server -DatacenterName $datacenterName
            } else {
                $objectPermissions = Get-ObjectPermissions -Server $Server
            }
            
            $allPermissions += $objectPermissions
            Write-Host "  Found $($objectPermissions.Count) object-level permissions" -ForegroundColor Green
        }
        
        # Process and enrich permission data
        Write-Host "  Processing permission data..." -ForegroundColor Yellow
        $processedPermissions = $allPermissions | ForEach-Object {
            Add-PermissionMetadata -Permission $_ -Server $Server
        }
        
        # Apply exclusion filtering if enabled
        if ($Config.ContainsKey('EnablePermissionExclusion') -and $Config.EnablePermissionExclusion -eq $true) {
            Write-Host "  Applying permission exclusions..." -ForegroundColor Yellow
            
            # Build exclusion file path
            $exclusionFilePath = $Config.ExclusionFilePath
            if (-not [System.IO.Path]::IsPathRooted($exclusionFilePath)) {
                # If relative path, make it relative to the script root
                $scriptRoot = $PSScriptRoot
                if (-not $scriptRoot) {
                    $scriptRoot = Split-Path -Parent $MyInvocation.PSCommandPath
                }
                $exclusionFilePath = Join-Path (Split-Path -Parent $scriptRoot) $exclusionFilePath
            }
            
            # Load exclusion patterns
            $exclusionPatterns = Read-ExclusionList -ExclusionFilePath $exclusionFilePath
            
            # Filter permissions
            $filteredPermissions = Filter-PermissionsByExclusion -Permissions $processedPermissions -ExclusionPatterns $exclusionPatterns -ShowExclusionStats $true
            
            Write-Host "Permission audit complete. Total permissions: $($filteredPermissions.Count)" -ForegroundColor Green
            return $filteredPermissions
        } else {
            Write-Host "Permission audit complete. Total permissions: $($processedPermissions.Count)" -ForegroundColor Green
            return $processedPermissions
        }
    }
    catch {
        Write-Error "Error during permission audit: $($_.Exception.Message)"
        throw
    }
}

function Get-GlobalPermissions {
    param(
        [Parameter(Mandatory = $true)]
        $Server
    )
    
    try {
        # Get root folder and its permissions
        $rootFolder = Get-Folder -Name "Datacenters" -Server $Server -ErrorAction Stop
        $permissions = Get-VIPermission -Entity $rootFolder -Server $Server -ErrorAction Stop
        
        $globalPermissions = @()
        
        foreach ($perm in $permissions) {
            $permissionObj = [PSCustomObject]@{
                Entity = "Global Root"
                EntityType = "Folder"
                EntityId = $rootFolder.Id
                Principal = $perm.Principal
                Role = $perm.Role
                Inherited = $perm.IsGroup
                Propagate = $perm.Propagate
                Source = "Global"
                CreatedDate = Get-Date
                ModifiedDate = Get-Date
            }
            $globalPermissions += $permissionObj
        }
        
        return $globalPermissions
    }
    catch {
        Write-Warning "Failed to retrieve global permissions: $($_.Exception.Message)"
        return @()
    }
}

function Get-ObjectPermissions {
    param(
        [Parameter(Mandatory = $true)]
        $Server,
        
        [Parameter()]
        [string]$DatacenterName
    )
    
    try {
        $objectPermissions = @()
        
        # Get entities to audit
        if ($DatacenterName) {
            Write-Host "    Focusing on datacenter: $DatacenterName" -ForegroundColor Cyan
            $datacenter = Get-Datacenter -Name $DatacenterName -Server $Server -ErrorAction Stop
            $entities = @($datacenter)
            
            # Get additional objects within the datacenter
            $entities += Get-Folder -Location $datacenter -Server $Server
            $entities += Get-Cluster -Location $datacenter -Server $Server
            $entities += Get-VMHost -Location $datacenter -Server $Server
            $entities += Get-VM -Location $datacenter -Server $Server
            $entities += Get-Datastore -Location $datacenter -Server $Server
        } else {
            Write-Host "    Auditing all vCenter objects..." -ForegroundColor Cyan
            $entities = @()
            $entities += Get-Datacenter -Server $Server
            $entities += Get-Folder -Server $Server
            $entities += Get-Cluster -Server $Server
            $entities += Get-VMHost -Server $Server
            $entities += Get-VM -Server $Server
            $entities += Get-Datastore -Server $Server
        }
        
        $processedCount = 0
        $totalEntities = $entities.Count
        
        foreach ($entity in $entities) {
            $processedCount++
            if ($processedCount % 100 -eq 0) {
                Write-Host "    Processed $processedCount/$totalEntities entities..." -ForegroundColor Gray
            }
            
            try {
                $permissions = Get-VIPermission -Entity $entity -Server $Server -ErrorAction SilentlyContinue
                
                foreach ($perm in $permissions) {
                    $permissionObj = [PSCustomObject]@{
                        Entity = $entity.Name
                        EntityType = $entity.GetType().Name -replace 'Impl$', ''
                        EntityId = $entity.Id
                        Principal = $perm.Principal
                        Role = $perm.Role
                        Inherited = $perm.IsGroup
                        Propagate = $perm.Propagate
                        Source = "Object"
                        CreatedDate = Get-Date
                        ModifiedDate = Get-Date
                        EntityPath = Get-EntityPath -Entity $entity
                    }
                    $objectPermissions += $permissionObj
                }
            }
            catch {
                Write-Debug "Could not retrieve permissions for entity: $($entity.Name) - $($_.Exception.Message)"
            }
        }
        
        return $objectPermissions
    }
    catch {
        Write-Warning "Failed to retrieve object permissions: $($_.Exception.Message)"
        return @()
    }
}

function Add-PermissionMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Permission,
        
        [Parameter(Mandatory = $true)]
        $Server
    )
    
    # Add role description
    $Permission | Add-Member -MemberType NoteProperty -Name "RoleDescription" -Value (Get-RoleDescription -RoleName $Permission.Role) -Force
    
    # Add principal type detection
    $principalType = if ($Permission.Principal -match '\\') { 
        "Domain Account" 
    } elseif ($Permission.Principal -match '@') { 
        "UPN Account" 
    } else { 
        "Local Account" 
    }
    $Permission | Add-Member -MemberType NoteProperty -Name "PrincipalType" -Value $principalType -Force
    
    # Add entity identifier for tooltip linking
    $Permission | Add-Member -MemberType NoteProperty -Name "EntityIdentifier" -Value (Get-EntityIdentifier -Permission $Permission) -Force
    
    return $Permission
}

function Get-EntityPath {
    param(
        [Parameter(Mandatory = $true)]
        $Entity
    )
    
    try {
        if ($Entity.Parent) {
            $parentPath = Get-EntityPath -Entity $Entity.Parent
            return "$parentPath/$($Entity.Name)"
        } else {
            return $Entity.Name
        }
    }
    catch {
        return $Entity.Name
    }
}

function Get-PermissionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Permissions
    )
    
    $summary = @{
        TotalPermissions = $Permissions.Count
        GlobalPermissions = ($Permissions | Where-Object { $_.Source -eq "Global" }).Count
        ObjectPermissions = ($Permissions | Where-Object { $_.Source -eq "Object" }).Count
        InheritedPermissions = ($Permissions | Where-Object { $_.Inherited }).Count
        DirectPermissions = ($Permissions | Where-Object { -not $_.Inherited }).Count
        PropagatingPermissions = ($Permissions | Where-Object { $_.Propagate }).Count
        UniqueRoles = ($Permissions | Select-Object -ExpandProperty Role -Unique).Count
        UniquePrincipals = ($Permissions | Select-Object -ExpandProperty Principal -Unique).Count
        UniqueEntities = ($Permissions | Select-Object -ExpandProperty Entity -Unique).Count
    }
    
    Write-Host "Permission Audit Summary:" -ForegroundColor Cyan
    Write-Host "   Total Permissions: $($summary.TotalPermissions)" -ForegroundColor White
    Write-Host "   Global Permissions: $($summary.GlobalPermissions)" -ForegroundColor Yellow
    Write-Host "   Object Permissions: $($summary.ObjectPermissions)" -ForegroundColor Yellow
    Write-Host "   Inherited Permissions: $($summary.InheritedPermissions)" -ForegroundColor Green
    Write-Host "   Direct Permissions: $($summary.DirectPermissions)" -ForegroundColor Green
    Write-Host "   Propagating Permissions: $($summary.PropagatingPermissions)" -ForegroundColor Blue
    Write-Host "   Unique Roles: $($summary.UniqueRoles)" -ForegroundColor Magenta
    Write-Host "   Unique Principals: $($summary.UniquePrincipals)" -ForegroundColor Magenta
    Write-Host "   Unique Entities: $($summary.UniqueEntities)" -ForegroundColor Magenta
    
    return $summary
}

Export-ModuleMember -Function Get-Permissions, Get-GlobalPermissions, Get-ObjectPermissions, Add-PermissionMetadata, Get-EntityPath, Get-PermissionSummary
