param (
    [string]$StorageAccountName,
    [string]$FileShareName,
    [System.String]$StorageAccountKey,
    [string]$BuildFilesPath,
    [string]$Version,
    [string]$DestinationPath = "C:\Program Files\ccure",
    [string]$SysprepPath = "C:\Windows\System32\Sysprep\Sysprep.exe",
    [string]$installPathSql = "C:\Program Files\SQLserver2022" #olasupo needs to find the path
    
)

#  Define variables for the service installation
$SourceFilesPath=Join-Path $BuildFilesPath "UC_$Version"
$AppDirectory = Join-Path $installPathSql $version "Copied" #"C:\Program Files\ccure\UC_4.10.368.368\Copied\" #olasupo needs to find the path


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

    # Example usage Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
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
    $sourceUri = "https://{0}.file.core.windows.net/{1}/{2}/*?{3}" -f $StorageAccountName, $FileShareName, $SourceFilesPath, $StorageAccountKey
    Write-Host "Copying files from Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    try {
        Start-Process -FilePath $global:azCopyPath -ArgumentList @("copy", "$sourceUri", "`"$DestinationPath`"", "--recursive", "--preserve-smb-info=true") -NoNewWindow -Wait
        Write-Host "---Files copied successfully to "`"$DestinationPath`""---" -ForegroundColor Green
    } catch {
        Write-Error "File copy failed: $_.Exception.Message"
        Exit 1
    }
}

function Get-NSSM {
    $NSSMDownloadUrl = "https://nssm.cc/release/nssm-2.24.zip" # Update to the desired version URL
    $NSSMExtractPath = "C:\Program Files\nssm"
    
    $NSSMZipPath = "$NSSMExtractPath\nssm.zip"

    if (-Not (Test-Path $NSSMExtractPath)) {
        New-Item -ItemType Directory -Path $NSSMExtractPath | Out-Null
    }

    Write-Host "Downloading NSSM..."
    Invoke-WebRequest -Uri $NSSMDownloadUrl -OutFile $NSSMZipPath

    Write-Host "Extracting NSSM..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($NSSMZipPath, $NSSMExtractPath)
    Remove-Item $NSSMZipPath

    Write-Host "NSSM downloaded and extracted to $NSSMExtractPath"
}

function Install-NSSMService {
    param (
        [string]$ServiceName,
        [string]$AppPath,
        [string]$AppDirectory,
        [string]$AppArguments
    )
    $global:NSSMPath = "$NSSMExtractPath\win64\nssm.exe"  
    # Ensure NSSM is available
    if (-Not (Test-Path $global:NSSMPath)) {
        Write-Host "NSSM not found at $global:NSSMPath. Please ensure NSSM is installed and the path is correct."
        Exit 1
    }

    # Install the service
    Write-Host "Installing service: $ServiceName"
    & $global:NSSMPath install $ServiceName $AppPath

    # Configure the service
    Write-Host "Configuring service: $ServiceName"
    & $global:NSSMPath set $ServiceName AppDirectory $AppDirectory
    & $global:NSSMPath set $ServiceName AppParameters $AppArguments

    Write-Host "Configuring service: $ServiceName to not restart on failure"
    & $global:NSSMPath set $ServiceName AppNoConsole 1 
    # & $global:NSSMPath set $ServiceName AppStopMethodSkip 5

    # Start the service
    Write-Host "Starting service: $ServiceName"
    & $global:NSSMPath start $ServiceName

    # Verify service status
    $ServiceStatus = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($ServiceStatus.Status -eq "Running") {
        Write-Host "Service $ServiceName is running successfully."
    } else {
        Write-Host "Service $ServiceName failed to start. Check the NSSM logs for details."
    }

}

function Copy-SQLFilesUsingAzCopy {
    $sourceUri = "https://{0}.file.core.windows.net/{1}/sqlserver2022/*?{2}" -f $StorageAccountName, $FileShareName, $StorageAccountKey
    Write-Host "Copying files from Azure File Share to the local directory using AzCopy..." -ForegroundColor Green
    try {
        Start-Process -FilePath $global:azCopyPath -ArgumentList @("copy", "$sourceUri", "`"$installPathSql`"", "--recursive", "--preserve-smb-info=true") -NoNewWindow -Wait
        Write-Host "---Files copied successfully to "`"$installPathSql`""---" -ForegroundColor Green
    } catch {
        Write-Error "File copy failed: $_.Exception.Message"
        Exit 1
    }
}

function Install-Sql {
    $ServiceName = "SQLserver"
    $AppPath = Join-Path -Path $installPathSql "Setup.exe"

# Check if the directory exists 
    if (Test-Path -Path $AppPath) { 
        Write-Host "Directory exists at $AppPath."} 
    else {
        Write-Output "Exiting script." 
        Exit 1 | Out-Null
    }

    # Construct the setup arguments
    $AppArguments = @(
        "/Q",
        "/ACTION=install",
        "/INSTANCENAME=CCUREINST",
        "/INSTANCEID=CCUREINST",
        "/SQLSVCACCOUNT=`"CCURE`"",
        "/SQLSVCPASSWORD=`"Password@14isgood`"",
        "/SQLSYSADMINACCOUNTS=`"CCUREADMIN`"",
        "/AGTSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`"",
        "/INSTALLPATH=`"C:\Program Files\Microsoft SQL Server`""
        "/IACCEPTSQLSERVERLICENSETERMS"
    )

    Install-NSSMService -ServiceName $ServiceName -AppPath $AppPath -AppDirectory $installPathSql -AppArguments $AppArguments
    Write-Output "SQL Server 2022 installation completed successfully."
}

function Install-Dashboard {
    $ServiceName = "DashboardService"
    $AppPath = Join-Path $DestinationPath "UC_$Version" "Copied\ISOImage\dashboard.exe" # Update to the path of dashboard.exe
    $AppDirectory = Join-Path $DestinationPath "UC_$Version" "Copied\ISOImage\" # Update to the startup directory
    # Command-line arguments for the application
    $AppArguments = "/SOURCE:`"C:\Users\adminolasupo\Desktop\UC_4.10.368.368\Copied\ISOImage`" /F:VictorAutoUpdateServer -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" /F:VictorApplicationServer -SqlServer:vm-osp-crossfir -VasServicePassword:UhaNA+9zcAqW48b5tm7u2w== -VasServiceDomainName:vm-osp-crossfir -VasServiceUsername:adminolasupo -VasServiceAccountType:2 -IntegratedSecurity:TRUE -MicrosoftEntraID:FALSE -VasLocalServiceAccount:vm-osp-crossfir\adminolasupo -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -IsSqlServerLocal:1 -AppServerType:0 -DBManagerExePath:`"C:\Program Files (x86)\JCI\Crossfire\DBManager`" -ServerType:1 -DBBuildInstallConfig:Standalone -VictorOnlyIsInstalled:0 -CCureClientIsInstalled:1 -VictorClientIsInstalled:0 -SqlConnectionString:`"Data Source=vm-osp-crossfir;Initial Catalog=master;Integrated Security=True;`" -WebSiteName:`"Default Web Site`" -EnhancedSecurity:1 -EncryptionSecurity:1 -SkipDBManager:1 -EncryptionPassPhrase:hWRH2meXkWeEbryZeN7LWFpuaLp2mXFawLNKnamcnDU= /F:Ccure9000Client -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -VasServer:localhost /F:CcureGoWebService -WebServiceDomainName:vm-osp-crossfir -WebServiceUsername:adminolasupo -LocalServiceAccount:0 -WebServicePassword:UhaNA+9zcAqW48b5tm7u2w== -VasServer:localhost -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -WebSiteName:`"Default Web Site`" /F:VictorWebService -SqlServer:vm-osp-crossfir -WebServiceDomainName:vm-osp-crossfir -WebServiceUsername:adminolasupo -WebServicePassword:UhaNA+9zcAqW48b5tm7u2w== -VasServer:localhost -IntegratedSecurity:TRUE -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -VasForWebServiceLocalOrRemote:2 -SqlConnectionString:`"Data Source=vm-osp-crossfir;Initial Catalog=master;Integrated Security=True;`" -WebSiteName:`"Default Web Site`" /F:CCUREAutoUpdateServer -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -CcureAutoUpdateInstallDate:12/13/2024 -WebSiteName:`"Default Web Site`" /F:victorClientAutoUpdatePackage /F:CCUREAutoUpdateClient -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" /F:CCPortal -CCurePortalPort:HTTPS -UseHTTPSPortal:1 -ServerMode:IIS -IpType:true -AllowRemoteConnections:true -CCurePortalPortNumber:443 -PortalServer:localhost -JCIInstallDirectory:`"C:\Program Files (x86)\JCI`" -WebserviceDevice:localhost -WebSiteName:`"Default Web Site`" /F:VictorWebClient -VictorWebPort:HTTPS -VictorWebPortNumber:443 -WebServiceUsername:vm-osp-crossfir\adminolasupo -VictorWebClientAdminUsername:vm-osp-crossfir\adminolasupo -VictorWebClientAdminPassword:UhaNA+9zcAqW48b5tm7u2w== -VictorWebClientAdminPasswordReenter:UhaNA+9zcAqW48b5tm7u2w== -WebServicePassword:UhaNA+9zcAqW48b5tm7u2w== -vWCServer:localhost"

 

    Install-NSSMService -ServiceName $ServiceName -AppPath `"$AppPath`" -AppDirectory `"$AppDirectory`" -AppArguments $AppArguments
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
    Get-NSSM
    Copy-SQLFilesUsingAzCopy
    Install-Sq
    Copy-BuildFilesUsingAzCopy
    Install-Dashboard
    # Set-FirewallRule -IPAddress "192.168.0.2" -Port 80 -Group "Web Traffic"
    Push-SystemPrep
} catch {
    Write-Error "An error occurred during script execution: $_.Exception.Message"
    Exit 1
}
