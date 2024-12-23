 #Requires -RunAsAdministrator

<#
.SYNOPSIS
    MS SQL Server silent installation script

.DESCRIPTION
    This script installs MS SQL Server unattended from the exe image.
    Transcript of the entire operation is recorded in the log file.
.NOTES
    Version: 1.1
#>

param(
    [string] $ExePath = $ENV:SQLSERVER_EXEPATH,
    [ValidateSet('SQL', 'AS', 'IS', 'MDS', 'Tools')]
    [string[]] $Features = @('SQL'),
    [string] $InstallDir =  "`"$Env:ProgramFiles\MicrosoftSQLServer`"",
    [string] $DataDir,
    [ValidateNotNullOrEmpty()]
    [string] $InstanceName = $Env:USERDOMAIN,
    [string] $ServiceAccountName = "$Env:USERDOMAIN\$Env:USERNAME",
    [string] $ServiceAccountPassword = "P@ssw0rd",
    [string[]] $SystemAdminAccounts = @("$Env:USERDOMAIN\$Env:USERNAME"),
    [string] $ProductKey
)

# Function: Ensure script is run as Administrator
function Confirm-RunAsAdmin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Please run this script as an Administrator!" -ForegroundColor Red
        exit
    }
}

# Function: Install necessary Windows features
function Install-WindowsFeatures {
    $rolesAndFeatures = @(
        'Web-Server',
        'Web-Common-Http',
        'Web-App-Dev',
        'Web-Security',
        'Server-Media-Foundation'
    )

    foreach ($feature in $rolesAndFeatures) {
        Write-Host "Installing feature: $feature" -ForegroundColor Cyan
        Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop
    }

    Write-Host "Installed Features:" -ForegroundColor Green
    Get-WindowsFeature | Where-Object { $_.InstallState -eq "Installed" }
}

# Function: Download SQL Server installer
function Get-Installer {
    param (
        [string] $ExePath,
        [string] $ScriptName
    )
    
    if (!$ExePath) {
        Write-Host "SQLSERVER_EXEPATH environment variable not specified, using default URL"
        $ExePath = "https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe"
    }

    $saveDir = Join-Path $Env:TEMP $ScriptName
    New-Item $saveDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    $exeName = $ExePath -split '/' | Select-Object -Last 1
    $savePath = Join-Path $saveDir $exeName

    if (-Not (Test-Path $savePath)) {
        Write-Host "Downloading installer..."
        Invoke-WebRequest -Uri $ExePath -OutFile $savePath

        if (Test-Path $savePath) {
            Write-Host "Download successful: $savePath"
        } else {
            Write-Host "Error: Failed to download installer." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Installer already exists at: $savePath"
    }

    return $savePath
}

# Function: Extract SQL Server files
function Expand-Installer {
    param (
        [string] $ExePath,
        [string] $DestinationPath
    )

    Write-Host "Extracting files to $DestinationPath..."
    Start-Process -FilePath $ExePath -ArgumentList "/Q /X:$DestinationPath" -Wait

    if (Test-Path $DestinationPath) {
        Write-Host "Extraction successful. Files are located at $DestinationPath"
    } else {
        Write-Host "Extraction failed. Please check the executable path or arguments." -ForegroundColor Red
        exit 1
    }
}

# Function: Construct installation command
function Build-InstallCommand {
    param (
        [string] $DestinationPath,
        [string[]] $Features,
        [string] $InstallDir,
        [string] $DataDir,
        [string] $InstanceName,
        [string] $ServiceAccountName,
        [string] $ServiceAccountPassword,
        [string[]] $SystemAdminAccounts,
        [string] $ProductKey
    )

    $cmd = @(
        "$DestinationPath/SETUP.EXE",
        '/Q',
        '/INDICATEPROGRESS',
        '/IACCEPTSQLSERVERLICENSETERMS',
        '/ACTION=install',
        '/UPDATEENABLED=false',
        "/INSTANCEDIR=`"$InstallDir`"",
        "/INSTALLSQLDATADIR=`"$DataDir`"",
        "/FEATURES=" + ($Features -join ','),
        "/SQLSYSADMINACCOUNTS=`"$($SystemAdminAccounts -join ' ')`"",
        '/SECURITYMODE=SQL',
        "/INSTANCENAME=$InstanceName",
        "/SQLSVCACCOUNT=`"$ServiceAccountName`"",
        "/SQLSVCPASSWORD=`"$ServiceAccountPassword`"",
        '/SQLSVCSTARTUPTYPE=automatic',
        '/AGTSVCSTARTUPTYPE=automatic',
        '/ASSVCSTARTUPTYPE=manual',
        "/PID=$ProductKey"
    )
    $cmd_out = $cmd = $cmd -notmatch '/.+?=("")?$'
    return $cmd_out
}

# Main Script Execution
Confirm-RunAsAdmin
Install-WindowsFeatures


$scriptName = (Split-Path -Leaf $PSCommandPath) -replace '\.ps1$', ''

if (-not $scriptName) {
    # Fallback to default name if PSCommandPath is not set
    $scriptName = "`"C:\Program Files\ccure`""
}

Write-Host "Using script name: $scriptName"

$start = Get-Date
Start-Transcript "$PSScriptRoot\$scriptName-$($start.ToString('s').Replace(':','-')).log"

$ExePath = Get-Installer -ExePath $ExePath -ScriptName $scriptName
$DestinationPath = "C:\SQLSetupFiles"
Expand-Installer -ExePath $ExePath -DestinationPath $DestinationPath

$installCmd = Build-InstallCommand -DestinationPath $DestinationPath -Features $Features -InstallDir $InstallDir -DataDir $DataDir -InstanceName $InstanceName -SaPassword $SaPassword -ServiceAccountName $ServiceAccountName -ServiceAccountPassword $ServiceAccountPassword -SystemAdminAccounts $SystemAdminAccounts -ProductKey $ProductKey

Write-Host "Executing installation command..."
Invoke-Expression ($installCmd -join ' ')

$totalMinutes = ((Get-Date) - $start).TotalMinutes
Write-Host ("Installation completed in {0:f1} minutes." -f $totalMinutes) -ForegroundColor Green

Stop-Transcript
 
