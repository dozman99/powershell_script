# Define the URL for the SQL Server 2022 ISO file
$isoUrl = "https://download.microsoft.com/download/SQLServer2022.iso"

# Define the path to save the downloaded ISO file
$isoPath = "C:\path\to\SQLServer2022.iso"

# Define the installation path
$installPath = "C:\SQLServer2022"

# Download the ISO file
if (-Not (Test-Path -Path $isoPath)) {
    Write-Output "Downloading SQL Server 2022 ISO..."
    Invoke-WebRequest -Uri $isoUrl -OutFile $isoPath
} else {
    Write-Output "SQL Server 2022 ISO already exists at $isoPath. Skipping download."
}

# Mount the ISO file
Write-Output "Mounting the ISO file..."
$mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru
$driveLetter = ($mountResult | Get-Volume).DriveLetter

if (-Not $driveLetter) {
    Write-Error "Failed to mount the ISO file. Ensure the path and file are valid."
    exit 1
}

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    Write-Output "Creating installation directory at $installPath..."
    New-Item -ItemType Directory -Path $installPath | Out-Null
}

# Copy the installation files from the mounted ISO to the installation directory
Write-Output "Copying installation files to $installPath..."
Copy-Item -Path "$driveLetter:\*" -Destination $installPath -Recurse -Force

# Run the SQL Server setup
Write-Output "Starting SQL Server setup..."
Start-Process -FilePath "$installPath\setup.exe" -ArgumentList "/Q /ACTION=install /FEATURES=SQLEngine /INSTANCENAME=SQL2022 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`" /AGTSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SAPWD=YourPassword" -Wait

# Dismount the ISO file
Write-Output "Dismounting the ISO file..."
Dismount-DiskImage -ImagePath $isoPath

Write-Output "SQL Server 2022 installation completed successfully."

