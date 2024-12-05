param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$SourceFilesPath,
    [string]$DestinationPath = "C:\Users\azureuser\Desktop\build",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
)

# Ensure the PowerShell execution policy allows the script to run
if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
}

# Download and Install AzCopy
Write-Host "Downloading AzCopy..." -ForegroundColor Green
Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "AzCopy.zip" -UseBasicParsing

Write-Host "Extracting AzCopy..." -ForegroundColor Green
Expand-Archive -Path "AzCopy.zip" -DestinationPath "C:\Program Files\AzCopy" -Force

# Set up AzCopy path
$azCopyPath = "C:\Program Files\AzCopy\azcopy_windows_amd64_10.27.1\azcopy.exe"

# Copy files from the Azure File Share to the local directory using AzCopy
Write-Host "Copying files from the Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
$sourceFilePath = "https://$StorageAccountName.file.core.windows.net/$FileShareName/$SourceFilesPath?$StorageAccountKey"
$azCopyCommand = "& '$azCopyPath' copy '$sourceFilePath' '$DestinationPath' --recursive=true --overwrite=true --trailing-dot string" 
Invoke-Expression $azCopyCommand
Write-Host "Files copied successfully to local directory." -ForegroundColor Green

# # Clean up AzCopy
# Write-Host "Cleaning up AzCopy..." -ForegroundColor Green
# Remove-Item -Path "AzCopy.zip" -Force

# Run Sysprep on the VM
# Write-Host "Running Sysprep..." -ForegroundColor Green
# try {
#     Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown" -Wait
#     Write-Host "Sysprep completed successfully." -ForegroundColor Green
# } catch {
#     Write-Error "Sysprep failed: $_.Exception.Message"
#     Exit 1
# }

