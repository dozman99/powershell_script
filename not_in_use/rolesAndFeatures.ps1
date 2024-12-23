# Ensure the script is run with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an Administrator!" -ForegroundColor Red
    exit
}

# Define the server roles and features to be installed
$rolesAndFeatures = @(
    'Web-Server',                # Web Server (IIS)
    'Web-Common-Http',           # Common HTTP Features for IIS
    'Web-App-Dev',               # Application Development for IIS
    'Web-Security',              # Security Features for IIS
    'Server-Media-Foundation'          # Media Foundation

)

# Install the roles and features
foreach ($feature in $rolesAndFeatures) {
    Write-Host "Installing feature: $feature" -ForegroundColor Cyan
    Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
}


# Verify the installation
Write-Host "Installed Features:" -ForegroundColor Green
Get-WindowsFeature | Where-Object { $_.InstallState -eq "Installed" }


