function Connect-VSphere {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        
        [Parameter()]
        [int]$Port = 443,
        
        [Parameter()]
        [string]$Protocol = "https"
    )
    
    try {
        Write-Host "Connecting to vCenter: $Server" -ForegroundColor Yellow
        
        # Set PowerCLI configuration to ignore certificate warnings
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session -WarningAction SilentlyContinue | Out-Null
        
        # Attempt connection
        $viServer = Connect-VIServer -Server $Server -Credential $Credential -Port $Port -Protocol $Protocol -ErrorAction Stop
        
        if ($viServer) {
            Write-Host "Successfully connected to vCenter: $($viServer.Name)" -ForegroundColor Green
            return $viServer
        }
    }
    catch {
        Write-Error "Failed to connect to vCenter server '$Server': $($_.Exception.Message)"
        return $null
    }
}

function Test-VSphereConnection {
    param(
        [Parameter(Mandatory = $true)]
        $Server
    )
    
    try {
        $null = Get-View -Id 'ServiceInstance' -Server $Server -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "vSphere connection appears to be inactive: $($_.Exception.Message)"
        return $false
    }
}

function Disconnect-VSphereSession {
    param(
        [Parameter(Mandatory = $true)]
        $Server,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-Host "Disconnecting from vCenter: $($Server.Name)" -ForegroundColor Yellow
        Disconnect-VIServer -Server $Server -Confirm:(!$Force) -Force:$Force
        Write-Host "Successfully disconnected from vCenter" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error during disconnection: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Connect-VSphere, Test-VSphereConnection, Disconnect-VSphereSession
