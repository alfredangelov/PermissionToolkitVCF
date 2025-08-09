# vCenter Credential Update Options

This toolkit now provides multiple ways to update your vCenter credentials in the SecretManagement vault:

## 1. Comprehensive Update Script

```powershell
.\Update-Credentials.ps1
```

**Features:**

- ✅ Full validation and error checking
- ✅ Shows current configuration and credentials
- ✅ Confirmation prompts with server details
- ✅ Comprehensive verification after update
- ✅ Professional output with next steps

**Parameters:**

- `-Force` - Skip confirmation prompts

## 2. Quick Update Script

```powershell
.\Quick-CredentialUpdate.ps1
```

**Features:**

- ✅ Minimal prompts for fast updates
- ✅ Shows current server and username
- ✅ Direct credential entry
- ✅ Simple success confirmation

## 3. PowerShell Function (Utils Module)

```powershell
Import-Module .\modules\Utils.psm1
Update-VCenterCredentials
```

**Features:**

- ✅ Available as part of the toolkit modules
- ✅ Can be called from other scripts
- ✅ Configurable parameters
- ✅ Integrated error handling

**Parameters:**

- `-Force` - Skip confirmation prompts
- `-ConfigPath` - Custom configuration file path

## Configuration Integration

All methods automatically:

- 🔍 Read the vCenter server from `shared/Configuration.psd1`
- 🔐 Store credentials in the SecretManagement vault as "SourceCred"
- ✅ Verify credential storage and retrieval
- 📋 Display current username for confirmation

## Usage Examples

### Standard Update

```powershell
# Interactive with confirmation
.\Update-Credentials.ps1

# Force update without confirmation
.\Update-Credentials.ps1 -Force
```

### Quick Update

```powershell
# Fast credential change
.\Quick-CredentialUpdate.ps1
```

### Programmatic Update

```powershell
# From PowerShell session
Import-Module .\modules\Utils.psm1
Update-VCenterCredentials -Force
```

## Next Steps After Update

1. **Test Connection:**

   ```powershell
   .\Validate-Configuration.ps1
   ```

2. **Run Analysis:**

   ```powershell
   .\Permission-Toolkit.ps1
   ```

All credential update methods ensure your toolkit is ready to connect to the vCenter server specified in your configuration file!
