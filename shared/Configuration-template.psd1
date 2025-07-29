@{
    # If $true, actions will be simulated and no changes will be made
    DryRun                = 'true'

    # vSphere source server connection details
    SourceServerHost      = 'vcenter.example.com'

    # Permission export options
    ExportGlobalPermissions = 'true'  # Export global permissions
    ExportNormalPermissions = 'false'   # Export normal (object-level) permissions
    
    # Optional: Tooltip configuration
    EnableTooltips = $false        # Set to $true to auto-enhance reports with tooltips
    TooltipTheme = 'Dark'          # Options: Dark, Light, Blue
    TooltipMaxWidth = 320          # Maximum tooltip width in pixels
    TooltipChunkSize = 300         # Number of tooltips to process per chunk (helps manage memory)
}
