param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$SourceFilesPath,
    [string]$DestinationPath = "C:\Users\ccureuser\Desktop\build",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
)

function Set-ExecutionPolicyIfNeeded {
    if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
        Write-Host "Setting execution policy to RemoteSigned..." -ForegroundColor Green
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    }
}

function Setup-Firewall {

    #https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/configure-with-command-line?tabs=powershell
    
    # If you find that the rules you create aren't enforced
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

    # shows how to add a basic firewall rule that blocks outbound traffic from a specific
    # application and local port to a Group Policy Object (GPO) in Active Directory
    # New-NetFirewallRule -DisplayName "Block Outbound Telnet" -Direction Outbound -Program %SystemRoot%\System32\tlntsvr.exe -Protocol TCP -LocalPort 23 -Action Block -PolicyStore domain.contoso.com\gpo_name

    # allow you to change rule properties and influence, but the rule maintains its unique identifier
    Set-NetFirewallRule -DisplayName "Allow Web 80" -RemoteAddress 192.168.0.2 #-Name xxx #unique identifier

    #we assume the query returns a single firewall rule
    # Get-NetFirewallPortFilter | ?{$_.LocalPort -eq 80} | Get-NetFirewallRule | ?{ $_.Direction -eq "Inbound" -and $_.Action -eq "Allow"} | Set-NetFirewallRule -RemoteAddress 192.168.0.2

    #Adding rules to a custom rule group Telnet firewall rules to the group Telnet Management
    # New-NetFirewallRule -DisplayName "Allow Inbound Telnet" -Direction Inbound -Program %SystemRoot%\System32\tlntsvr.exe -RemoteAddress LocalSubnet -Action Allow -Group "Telnet Management"
    # New-NetFirewallRule -DisplayName "Block Outbound Telnet" -Direction Outbound -Program %SystemRoot%\System32\tlntsvr.exe -RemoteAddress LocalSubnet -Action Allow -Group "Telnet Management"






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

function Copy-FilesUsingAzCopy {
    $sourceUri = "https://$StorageAccountName.file.core.windows.net/$FileShareName/$SourceFilesPath?$StorageAccountKey"
    if (!(Test-Path $DestinationPath)) {
        Write-Host "Creating destination path: $DestinationPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $DestinationPath -Force
    }

    Write-Host "Copying files from Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    try {
        Start-Process -FilePath $global:azCopyPath -ArgumentList @("copy", "$sourceUri", "$DestinationPath", "--recursive", "--preserve-smb-info=true") -NoNewWindow -Wait
        Write-Host "Files copied successfully to $DestinationPath." -ForegroundColor Green
    } catch {
        Write-Error "File copy failed: $_.Exception.Message"
        Exit 1
    }
}

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

# Main script execution
try {
    Set-ExecutionPolicyIfNeeded
    Install-AzCopy
    Copy-FilesUsingAzCopy
    Run-Sysprep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
