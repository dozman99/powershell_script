param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$SourceFilesPath,
    [string]$DestinationPath = "C:\Program Files\ccure",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe",
    [string]$SqlSetupDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us",
    [string]$SqlSetupPath = "C:\setup.exe",
    [string]$InstanceName = "DEFAULTINST",
    [string]$InstanceId = "ccure",
    [string]$SqlSvcAccount = "ccure",
    [string]$SqlSvcPassword = "ThisIsMyPass4now.1]",
    [string]$SqlSysAdminAccount = "adminccure"
)

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

    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

    New-NetFirewallRule -DisplayName "Allow Inbound to $Port" `
        -Direction Inbound `
        -RemoteAddress $IPAddress `
        -Protocol $Protocol `
        -LocalPort $Port `
        -Action Allow `
        -Group $Group

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

    Remove-Item -Path "AzCopy.zip" -Force

    $global:azCopyPath = (Get-ChildItem "C:\Program Files\AzCopy" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName + "\azcopy.exe"
    if (!(Test-Path $global:azCopyPath)) {
        Write-Error "AzCopy installation failed. Ensure the file exists in 'C:\Program Files\AzCopy'."
        Exit 1
    }
    Write-Host "AzCopy installed at $global:azCopyPath" -ForegroundColor Green
}

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

function Install-SystemPrep {
    Write-Host "Running Sysprep..." -ForegroundColor Green
    try {
        Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown" -Wait
        Write-Host "Sysprep completed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Sysprep failed: $_.Exception.Message"
        Exit 1
    }
}

function Install-Sql {
    Write-Host "Downloading SQL Server setup..." -ForegroundColor Green
    try {
        Invoke-WebRequest -Uri $SqlSetupDownloadUrl -OutFile $SqlSetupPath -ErrorAction Stop
        Write-Host "SQL Server setup downloaded successfully."
    } catch {
        Write-Error "Failed to download SQL Server setup. Exiting."
        Exit 1
    }

    if (-Not (Test-Path $SqlSetupPath)) {
        Write-Error "SQL Server setup file not found. Exiting."
        Exit 1
    }

    Write-Host "Installing SQL Server..." -ForegroundColor Green
    try {
        & $SqlSetupPath /Q /ACTION=Download `
            /LANGUAGE="en-US" `
            /ENU `
            /IACCEPTSQLSERVERLICENSETERMS `
            /HIDEPROGRESSBAR `
            /MEDIAPATH="C:\Program Files\SQLServer2022" `
            /INSTALLPATH="=c:\Program Files\Microsoft SQL Server" `
            /MEDIATYPE=ISO

        Write-Host "SQL Server installation completed successfully."
    } catch {
        Write-Error "SQL Server installation failed: $_.Exception.Message"
        Exit 1
    }
}

# Main script execution
try {
    # Set-ExecutionPolicyIfNeeded
    # Install-AzCopy
    # Copy-FilesUsingAzCopy
    Install-Sql
    # Install-SystemPrep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
