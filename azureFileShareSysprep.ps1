param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [string]$StorageAccountKey,
    [string]$DriveLetter = "Z:",
    [string]$SourceFilesPath,
    [string]$DestinationPath,
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe"
)

# Ensure the PowerShell execution policy allows the script to run
if ((Get-ExecutionPolicy) -ne "RemoteSigned") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
}

# Define required modules
$requiredModules = @("Az", "AzureRM")

# Check and install required modules
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -Scope CurrentUser
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to install module '$module': $_.Exception.Message"
            Exit 1
        }
    } else {
        Write-Host "Module '$module' is already installed." -ForegroundColor Green
    }
}

# Securely retrieve credentials (optional example for Key Vault integration)
# Uncomment if using Azure Key Vault to retrieve the Storage Account Key
# $StorageAccountKey = (Get-AzKeyVaultSecret -VaultName "YourVaultName" -Name "YourSecretName").SecretValueText

# Step 1: Mount the Azure File Share as a Drive
Write-Host "Mounting Azure File Share..." -ForegroundColor Green
try {
    $Credential = New-Object PSCredential -ArgumentList "Azure\$StorageAccountName", (ConvertTo-SecureString -String $StorageAccountKey -AsPlainText -Force)
    New-PSDrive -Name $DriveLetter.Replace(":", "") -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist -Credential $Credential
    if (Test-Path $DriveLetter) {
        Write-Host "Azure File Share mounted successfully at $DriveLetter." -ForegroundColor Green
    } else {
        throw "Failed to mount Azure File Share."
    }
} catch {
    Write-Error $_.Exception.Message
    Exit 1
}

# Step 2: Copy files from the Azure File Share to the local directory
Write-Host "Copying files from the Azure File Share to the local directory..." -ForegroundColor Green
try {
    if (!(Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }
    Copy-Item -LiteralPath "$DriveLetter\$SourceFilesPath\*" -Destination $DestinationPath -Recurse -Force
    Write-Host "Files copied successfully to $DestinationPath." -ForegroundColor Green
} catch {
    Write-Error "Failed to copy files from $SourceFilesPath to $DestinationPath: $_.Exception.Message"
    # Unmount drive if mounted
    Remove-PSDrive -Name $DriveLetter.Replace(":", "") -Force
    Exit 1
}

# Step 3: Run Sysprep on the VM
Write-Host "Preparing to run Sysprep..." -ForegroundColor Green
$confirmSysprep = Read-Host "Are you sure you want to run Sysprep? (Y/N)"
if ($confirmSysprep -ne "Y") {
    Write-Host "Sysprep operation canceled." -ForegroundColor Yellow
    # Unmount drive before exit
    Remove-PSDrive -Name $DriveLetter.Replace(":", "") -Force
    Exit
}

Write-Host "Running Sysprep..." -ForegroundColor Green
try {
    Start-Process -FilePath $SysprepPath -ArgumentList "/oobe /generalize /shutdown" -Wait
    Write-Host "Sysprep completed successfully." -ForegroundColor Green
} catch {
    Write-Error "Sysprep failed: $_.Exception.Message"
    # Unmount drive if mounted
    Remove-PSDrive -Name $DriveLetter.Replace(":", "") -Force
    Exit 1
}

# Step 4: Clean Up
Write-Host "Cleaning up..." -ForegroundColor Green
try {
    Remove-PSDrive -Name $DriveLetter.Replace(":", "") -Force
    Write-Host "Drive $DriveLetter unmounted successfully." -ForegroundColor Green
} catch {
    Write-Warning "Failed to unmount drive $DriveLetter. Please unmount it manually."
}
