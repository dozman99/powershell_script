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

function Set-RunOnceKey {
    param (
        [string]$KeyName,          # The name of the RunOnce entry
        [string]$Command           # The command to execute
    )

    # Registry path for system-wide RunOnce
    $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

    try {
        # Ensure the RunOnce path exists
        if (-not (Test-Path $runOncePath)) {
            New-Item -Path $runOncePath -Force | Out-Null
        }

        # Set the RunOnce key with the specified command
        Set-ItemProperty -Path $runOncePath -Name $KeyName -Value $Command

        # Confirm success
        Write-Host "RunOnce key created (System-wide): $KeyName -> $Command" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create the system-wide RunOnce key: $_"
    }
}


function Push-SystemPrep {
    Write-Host "Running Sysprep..." -ForegroundColor Green
    try {
        Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown" -Wait
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
    Set-RunOnceKey -KeyName "RunAppInstallScript" -Command "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$appInstallScriptPath`""

    Push-SystemPrep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
