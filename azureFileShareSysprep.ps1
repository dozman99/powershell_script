param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$SourceFilesPath,
    [string]$DestinationPath = "C:\Users\azureuser\Desktop\build",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
)

function Set-ExecutionPolicyIfNeeded {
    if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
    }
}

function Install-AzCopy {
    Write-Host "Downloading AzCopy..." -ForegroundColor Green
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "AzCopy.zip" -UseBasicParsing

    Write-Host "Extracting AzCopy..." -ForegroundColor Green
    Expand-Archive -Path "AzCopy.zip" -DestinationPath "C:\Program Files\AzCopy" -Force

    Write-Host "Cleaning up AzCopy download files..." -ForegroundColor Green
    Remove-Item -Path "AzCopy.zip" -Force

    $global:azCopyPath = (Get-ChildItem "C:\Program Files\AzCopy\*" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName + "\azcopy.exe"
}

function Copy-FilesUsingAzCopy {
    $sourceUri = "https://$StorageAccountName.file.core.windows.net/$FileShareName/$SourceFilesPath?$StorageAccountKey"
    $azCopyCommand = "& '$global:azCopyPath' copy '$sourceUri' '$DestinationPath' --recursive --preserve-smb-info=true"

    Write-Host "Copying files from the Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    Invoke-Expression $azCopyCommand
    Write-Host "Files copied successfully to local directory." -ForegroundColor Green
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
Set-ExecutionPolicyIfNeeded
Install-AzCopy
Copy-FilesUsingAzCopy
Run-Sysprep
