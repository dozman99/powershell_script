
# README

## Overview

This PowerShell script automates the process of copying files from an Azure File Share to a local directory, setting firewall rules, and running Sysprep on a Windows machine. The main functionalities include:

- **Set Execution Policy**: Ensures that the PowerShell execution policy is set to allow the script to run.
- **Install AzCopy**: Downloads and installs the latest version of AzCopy, a tool for efficient data transfer to and from Azure Storage.
- **Copy Files Using AzCopy**: Copies files from an Azure File Share to a specified local directory.
- **Set Firewall Rules** *(Optional)*: Configures inbound and outbound firewall rules for specified IP addresses and ports.
- **Run Sysprep**: Executes the Sysprep tool to prepare the system for imaging.

---

## Prerequisites

- **Administrative Privileges**: The script must be run with administrator rights.
- **PowerShell**: Ensure that PowerShell is available on the system.
- **Internet Access**: Required for downloading AzCopy.
- **Azure Storage Account**: Access to an Azure Storage Account with a File Share.
- **AzCopy**: The script will install AzCopy if it's not already installed.

---

## Parameters

The script accepts the following parameters:

- **`-StorageAccountName`** *(String, Required)*: The name of your Azure Storage Account.
- **`-FileShareName`** *(String, Required)*: The name of the File Share within your storage account.
- **`-StorageAccountKey`** *(String, Required)*: The access key for your Azure Storage Account.
- **`-SourceFilesPath`** *(String, Required)*: The path within the File Share from which to copy files.
- **`-DestinationPath`** *(String, Optional)*: The local directory where files will be copied to. Default is `C:\Program Files\ccure`.
- **`-SysprepPath`** *(String, Optional)*: The path to the Sysprep executable. Default is `C:\Windows\System32\Sysprep\Sysprep.exe`.

---

## Usage

### Running the Script

1. **Open PowerShell as Administrator**:
   - Right-click on PowerShell and select **"Run as administrator"**.

2. **Execute the Script with Parameters**:

   ```powershell
   .\YourScriptName.ps1 -StorageAccountName "<YourStorageAccountName>" -FileShareName "<YourFileShareName>" -StorageAccountKey "<YourStorageAccountKey>" -SourceFilesPath "<SourcePathInFileShare>"
   ```

   Replace the placeholders with your actual values.

### Example

```powershell
.\AutomatedDeployment.ps1 `
    -StorageAccountName "myAzureStorage" `
    -FileShareName "myFileShare" `
    -StorageAccountKey "abc123def456ghi789jkl==" `
    -SourceFilesPath "installers/app" `
    -DestinationPath "D:\DeploymentFiles" `
    -SysprepPath "C:\Windows\System32\Sysprep\Sysprep.exe"
```

---

## Script Details

### Parameters Definition

```powershell
param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$SourceFilesPath,
    [string]$DestinationPath = "C:\Program Files\ccure",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
)
```

### Functions

#### 1. `Set-ExecutionPolicyIfNeeded`

Ensures the PowerShell execution policy is set to `RemoteSigned` for the current process.

```powershell
function Set-ExecutionPolicyIfNeeded {
    if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
        Write-Host "Setting execution policy to RemoteSigned..." -ForegroundColor Green
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    }
}
```

#### 2. `Set-FirewallRule` *(Optional)*

Configures firewall rules.

```powershell
function Set-FirewallRule {
    param (
        [string]$IPAddress,
        [int]$Port,
        [string]$Group,
        [string]$Protocol = "TCP"
    )

    # Enable the firewall for all profiles: Domain, Public, and Private
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

    # Add a rule to allow inbound traffic to the specified port and IP address
    New-NetFirewallRule -DisplayName "Allow Inbound to $Port" `
        -Direction Inbound `
        -RemoteAddress $IPAddress `
        -Protocol $Protocol `
        -LocalPort $Port `
        -Action Allow `
        -Group $Group

    # Add a rule to block outbound traffic to the specified port and IP address
    New-NetFirewallRule -DisplayName "Block Outbound to $Port" `
        -Direction Outbound `
        -RemoteAddress $IPAddress `
        -Protocol $Protocol `
        -LocalPort $Port `
        -Action Block `
        -Group $Group

    # Example usage:
    # Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
}
```

#### 3. `Install-AzCopy`

Downloads and installs AzCopy if it's not already installed.

```powershell
function Install-AzCopy {
    Write-Host "Downloading AzCopy..." -ForegroundColor Green
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "AzCopy.zip" -UseBasicParsing

    Write-Host "Extracting AzCopy..." -ForegroundColor Green
    Expand-Archive -Path "AzCopy.zip" -DestinationPath "C:\Program Files\AzCopy" -Force

    Write-Host "Cleaning up AzCopy download files..." -ForegroundColor Green
    Remove-Item -Path "AzCopy.zip" -Force

    $global:azCopyPath = (Get-ChildItem "C:\Program Files\AzCopy" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName + "\azcopy.exe"
    if (!(Test-Path $global:azCopyPath)) {
        Write-Error "AzCopy installation failed. Ensure the file exists in 'C:\Program Files\AzCopy'."
        Exit 1
    }
    Write-Host "AzCopy installed at $global:azCopyPath" -ForegroundColor Green
}
```

#### 4. `Copy-FilesUsingAzCopy`

Copies files from the Azure File Share to the local directory using AzCopy.

```powershell
function Copy-FilesUsingAzCopy {
    $sourceUri = "https://$StorageAccountName.file.core.windows.net/$FileShareName/$SourceFilesPath" + "?" + "$StorageAccountKey"
    Write-Host "Copying files from Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    try {
        Start-Process -FilePath $global:azCopyPath -ArgumentList @("copy", "$sourceUri", "`"$DestinationPath`"", "--recursive", "--preserve-smb-info=true") -NoNewWindow -Wait
        Write-Host "---Files copied successfully to "`"$DestinationPath`""---" -ForegroundColor Green
    } catch {
        Write-Error "File copy failed: $_.Exception.Message"
        Exit 1
    }
}
```

#### 5. `Run-Sysprep`

Runs the Sysprep tool with specified arguments.

```powershell
function Run-Sysprep {
    Write-Host "Running Sysprep..." -ForegroundColor Green
    try {
        Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown" -Wait
        Write-Host "Sysprep completed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Sysprep failed: $_.Exception.Message"
        Exit 1
    }
}
```

---

## Main Script Execution

The main script execution flow:

```powershell
# Main script execution
try {
    Set-ExecutionPolicyIfNeeded
    Install-AzCopy
    Copy-FilesUsingAzCopy
    # Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
    Run-Sysprep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
```

**Note**: The `Set-FirewallRule` function is included but commented out by default. Uncomment and modify the parameters as needed.

---

## Execution Flow

1. **Set Execution Policy**: Calls `Set-ExecutionPolicyIfNeeded` to ensure the script can run.
2. **Install AzCopy**: Calls `Install-AzCopy` to download and set up AzCopy.
3. **Copy Files**: Calls `Copy-FilesUsingAzCopy` to transfer files from Azure to local storage.
4. **Set Firewall Rules** *(Optional)*: The `Set-FirewallRule` function is provided but not called in the script. Uncomment and modify as needed.
5. **Run Sysprep**: Calls `Run-Sysprep` to prepare the system for imaging.

---

## Notes

- **Firewall Configuration**: The `Set-FirewallRule` function is included but not activated in the main script. To use it, uncomment the relevant line under the main script execution and provide the necessary parameters.
- **AzCopy Installation Directory**: The script installs AzCopy to `C:\Program Files\AzCopy`. Ensure this directory is accessible and has the necessary permissions.
- **Sysprep Warning**: Running Sysprep will generalize the system and shut it down. Ensure this is intended and save all work before running.
- **Error Handling**: The script includes `try-catch` blocks to handle exceptions and will exit with code `1` upon failure.
- **Logging**: Outputs are colored for better readability:
  - **Green**: Informational messages.
  - **Red**: Error messages.

---

## Safety Precautions

- **Backup Important Data**: Before running the script, back up any important data.
- **Test Environment**: It's recommended to test the script in a virtual machine or test environment first.
- **Verify Parameters**: Double-check all parameter values, especially paths and keys.

---

## Troubleshooting

- **Execution Policy Errors**: If you encounter execution policy errors, ensure that you are running PowerShell as administrator.
- **AzCopy Installation Failures**: If AzCopy fails to install, manually download and install it from [Microsoft Docs](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10).
- **File Copy Failures**: Verify that the `StorageAccountName`, `FileShareName`, `StorageAccountKey`, and `SourceFilesPath` are correct and that the network allows access to Azure Storage.
- **Sysprep Issues**: Check the Sysprep logs located in `%WINDIR%\System32\Sysprep\Panther` for detailed information if Sysprep fails.

---

## References

- **AzCopy Documentation**: [Use AzCopy to copy data to and from Azure Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
- **Sysprep Documentation**: [Sysprep (System Preparation) Overview](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--system-preparation--overview)

---

## Version History

- **v1.0**: Initial release with core functionalities:
  - Execution policy check.
  - AzCopy installation.
  - File copying from Azure File Share.
  - Optional firewall rule configuration.
  - Sysprep execution.

---

*Please ensure all credentials and sensitive information are secured.*
