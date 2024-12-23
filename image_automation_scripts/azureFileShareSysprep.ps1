param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [System.String]$StorageAccountKey,
    [string]$Version,
    [string]$DestinationPath = "C:\Program Files\ccure",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"    
)

#  Define variables for the service installation
$appInstallScriptPath = Join-Path $DestinationPath "ccureAppInstall.ps1"
$UnattendFilePath = Join-Path $DestinationPath "unattend.xml"

function Set-ExecutionPolicyIfNeeded {
    if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
        Write-Host "Setting execution policy to RemoteSigned..." -ForegroundColor Green
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    }
}

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
    # Example usage Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
}

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

function Copy-BuildFilesUsingAzCopy {
    $sourceUri = "https://{0}.file.core.windows.net/{1}/*?{2}" -f $StorageAccountName, $FileShareName, $StorageAccountKey
    Write-Host "Copying files from Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    try {
        Start-Process -FilePath $global:azCopyPath -ArgumentList @("copy", "$sourceUri", "`"$DestinationPath`"", "--recursive", "--preserve-smb-info=true") -NoNewWindow -Wait
        Write-Host "---Files copied successfully to "`"$DestinationPath`""---" -ForegroundColor Green
    } catch {
        Write-Error "File copy failed: $_.Exception.Message"
        Exit 1
    }
}

function Add-GlobalEnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    try {
        # Add the environment variable to the registry
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name $Name -Value $Value -Force
        # Notify the system of the environment variable change
        [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)

        Write-Output "Environment variable '$Name' has been added with the value: '$Value'."
    } catch {
        Write-Error "Failed to add the environment variable '$Name'. Error: $_"
    }
}

function Add-UnattendFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UnattendFilePath,    # Path to save the unattend.xml file

        [Parameter(Mandatory = $true)]
        [string]$AppInstallScriptPath # Path to the application install script
    )

    # Create the XML content dynamically
    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <RunSynchronous>
        <RunSynchronousCommand>
          <Order>1</Order>
          <Path>powershell.exe -ExecutionPolicy Bypass -File `"$AppInstallScriptPath`"</Path>
          <Description>Run Application Install Script</Description>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
"@

    # Write the XML content to the file
    $xmlContent | Out-File -FilePath $UnattendFilePath -Encoding utf8 -Force

    # Verify file creation
    if (Test-Path $UnattendFilePath) {
        Write-Host "Unattend file created successfully at: $UnattendFilePath"
    } else {
        Write-Host "Failed to create the unattend file." -ForegroundColor Red
    }
}

function Push-SystemPrep {
    Write-Host "Running Sysprep..." -ForegroundColor Green
    try {
        Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown /unattend:$unattendFile" -Wait
        Write-Host "Sysprep completed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Sysprep failed: $_.Exception.Message"
        Exit 1
    }
}

# Main script execution
try {
    Set-ExecutionPolicyIfNeeded
    Install-AzCopy
    Copy-BuildFilesUsingAzCopy
    # Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
    Add-GlobalEnvironmentVariable -Name "CCUREBUILD" -Value $Version
    Add-UnattendFile -UnattendFilePath $UnattendFilePath -AppInstallScriptPath $appInstallScriptPath
    Push-SystemPrep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
