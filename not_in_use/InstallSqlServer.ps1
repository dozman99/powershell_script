#Requires -RunAsAdministrator

<#
.SYNOPSIS
    MS SQL Server silent installation script

.DESCRIPTION
    This script installs MS SQL Server unattended from the exe image.
    Transcript of entire operation is recorded in the log file.

    The script lists parameters provided to the native setup but hides sensitive data. See the provided
    links for SQL Server silent install details.
.NOTES
    Version: 1.1
#>
param(
    # Path to exe file, if empty and current directory contains single exe file, it will be used.
    [string] $ExePath = $ENV:SQLSERVER_EXEPATH,

    # Sql Server features, see https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-2016-from-the-command-prompt#Feature
    [ValidateSet( 'SQL', 'AS', 'IS', 'MDS', 'Tools')]
    [string[]] $Features = @('SQL'),

    # Specifies a nondefault installation directory
    [string] $InstallDir,

    # Data directory, by default "$Env:ProgramFiles\Microsoft SQL Server"
    [string] $DataDir,

    # Service name. Mandatory, by default MSSQLSERVER
    [ValidateNotNullOrEmpty()]
    [string] $InstanceName = '$Env:USERDOMAIN',

    # sa user password. If empty, SQL security mode (mixed mode) is disabled
    [string] $SaPassword = "P@ssw0rd",

    # Username for the service account, see https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-2016-from-the-command-prompt#Accounts
    # Optional, by default 'NT Service\MSSQLSERVER'
    [string] $ServiceAccountName, # = "$Env:USERDOMAIN\$Env:USERNAME",

    # Password for the service account, should be used for domain accounts only
    # Mandatory with ServiceAccountName
    [string] $ServiceAccountPassword,

    # List of system administrative accounts in the form <domain>\<user>
    # Mandatory, by default current user will be added as system administrator
    [string[]] $SystemAdminAccounts = @("$Env:USERDOMAIN\$Env:USERNAME"),

    # Product key, if omitted, evaluation is used unless VL edition which is already activated
    [string] $ProductKey

)



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
    'Server-Media-Foundation'    # Media Foundation
)

# Install the roles and features
foreach ($feature in $rolesAndFeatures) {
    Write-Host "Installing feature: $feature" -ForegroundColor Cyan
    Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
}

# Verify the installation
Write-Host "Installed Features:" -ForegroundColor Green
Get-WindowsFeature | Where-Object { $_.InstallState -eq "Installed" }






$ErrorActionPreference = 'STOP'
$scriptName = (Split-Path -Leaf $PSCommandPath).Replace('.ps1', '')

$start = Get-Date
Start-Transcript "$PSScriptRoot\$scriptName-$($start.ToString('s').Replace(':','-')).log"

# Check if ExePath is provided
if (!$ExePath) {
    Write-Host "SQLSERVER_EXEPATH environment variable not specified, using default URL"
    
    # Define the default URL for the SQL Server installer
    $ExePath = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
    
    # Directory to save the downloaded installer
    $saveDir = Join-Path $Env:TEMP $scriptName
    New-item $saveDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    # Define the name of the installer
    $exeName = $ExePath -split '/' | Select-Object -Last 1
    $savePath = Join-Path $saveDir $exeName

    # Download the installer if it doesn't already exist
    if (-Not (Test-Path $savePath)) {
        Write-Host "Downloading installer..."
        Invoke-WebRequest -Uri $ExePath -OutFile $savePath

        # Verify download success
        if (Test-Path $savePath) {
            Write-Host "Download successful: $savePath"
        } else {
            Write-Host "Error: Failed to download installer."
            exit 1
        }
    } else {
        Write-Host "Installer already exists at: $savePath"
    }

    # Set the ExePath variable to the downloaded file
    $ExePath = $savePath
}

Write-Host "`nExePath: $ExePath"

$DestinationPath = "C:\SQLSetupFiles"

# Run the executable with extraction flags
Write-Host "Extracting files to $DestinationPath..."
Start-Process -FilePath $ExePath -ArgumentList "/Q /X:$DestinationPath" -Wait

# Check if the files were extracted successfully
if (Test-Path $DestinationPath) {
    Write-Host "Extraction successful. Files are located at $DestinationPath"
} else {
    Write-Host "Extraction failed. Please check the executable path or arguments."
    exit 1
}


Get-CimInstance win32_process | ? { $_.commandLine -like '*SETUP.EXE*/ACTION=install*' } | % {
    Write-Host "Sql Server installer is already running, killing it:" $_.Path  "pid: " $_.processId
    Stop-Process $_.processId -Force
}

$cmd =@(
    "$DestinationPath/SETUP.EXE"
    '/Q'                                # Silent install
    '/INDICATEPROGRESS'                 # Specifies that the verbose Setup log file is piped to the console
    '/IACCEPTSQLSERVERLICENSETERMS'     # Must be included in unattended installations
    '/ACTION=install'                   # Required to indicate the installation workflow
    '/UPDATEENABLED=false'              # Should it discover and include product updates.

    "/INSTANCEDIR=""$InstallDir"""
    "/INSTALLSQLDATADIR=""$DataDir"""

    "/FEATURES=" + ($Features -join ',')

    #Security
    "/SQLSYSADMINACCOUNTS=""$SystemAdminAccounts"""
    '/SECURITYMODE=SQL'                 # Specifies the security mode for SQL Server. By default, Windows-only authentication mode is supported.
    "/SAPWD=""$SaPassword"""            # Sa user password

    "/INSTANCENAME=$InstanceName"       # Server instance name

    "/SQLSVCACCOUNT=""$ServiceAccountName"""
    "/SQLSVCPASSWORD=""$ServiceAccountPassword"""

    # Service startup types
    "/SQLSVCSTARTUPTYPE=automatic"
    "/AGTSVCSTARTUPTYPE=automatic"
    "/ASSVCSTARTUPTYPE=manual"

    "/PID=$ProductKey"
)

# remove empty arguments
$cmd_out = $cmd = $cmd -notmatch '/.+?=("")?$'

# show all parameters but remove password details
Write-Host "Install parameters:`n"
'SAPWD', 'SQLSVCPASSWORD' | % { $cmd_out = $cmd_out -replace "(/$_=).+", '$1"****"' }
$cmd_out[1..100] | % { $a = $_ -split '='; Write-Host '   ' $a[0].PadRight(40).Substring(1), $a[1] }
Write-Host

"$cmd_out"
Invoke-Expression "$cmd"
# if ($LastExitCode) {
#     if ($LastExitCode -ne 3010) { throw "SqlServer installation failed, exit code: $LastExitCode" }
#     Write-Warning "SYSTEM REBOOT IS REQUIRED"
# }



"`nInstallation length: {0:f1} minutes" -f ((Get-Date) - $start).TotalMinutes


