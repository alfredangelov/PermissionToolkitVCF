@{
    # If $true, actions will be simulated and no changes will be made
    DryRun                = 'true'

    # vSphere source server connection details
    SourceServerHost      = 'vcenter.example.com'

    # Permission export options
    ExportGlobalPermissions = 'true'  # Export global permissions
    ExportNormalPermissions = 'false'   # Export normal (object-level) permissions
}
