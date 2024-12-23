# Define parameters
$sourcePath = "C:\Program Files\ccure\build%5CUC_4.10.397.397\Copied\ISOImage"
$installDir = "C:\Program Files (x86)\JCI"
$sqlServer = $Env:USERDOMAIN
$sqlPassword = "P@ssw0rd"
$username = $Env:USERNAME
$connectionString = "Data Source=$sqlServer;Initial Catalog=master;Integrated Security=False;User ID=sa;Password=$sqlPassword;"
$encryptionPassPhrase = "hWRH2meXkWeEbryZeN7LWFpuaLp2mXFawLNKnamcnDU="
$webSiteName = "Default Web Site"
$ccurePortalPortNumber = 443
$victorWebClientPassword = "UhaNA+9zcAqW48b5tm7u2w=="

# Execute the command
& "$sourcePath\bin\Dashboard.exe" `
    /SOURCE:$sourcePath `
    /F:VictorAutoUpdateServer `
    -JCIInstallDirectory:$installDir `
    /F:VictorApplicationServer `
    -SqlServer:$sqlServer `
    -SQLServerPassword:$sqlPassword `
    -VasServiceDomainName:$sqlServer `
    -VasServiceUsername:$username `
    -SQLServerUsername:"sa" `
    -VasServiceAccountType:1 `
    -IntegratedSecurity:FALSE `
    -MicrosoftEntraID:FALSE `
    -VasLocalServiceAccount:"$sqlServer\$username" `
    -IsSqlServerLocal:1 `
    -AppServerType:0 `
    -DBManagerExePath:"$installDir\Crossfire\DBManager" `
    -ServerType:1 `
    -DBBuildInstallConfig:Standalone `
    -VictorOnlyIsInstalled:0 `
    -CCureClientIsInstalled:1 `
    -VictorClientIsInstalled:0 `
    -SqlConnectionString:$connectionString `
    -WebSiteName:$webSiteName `
    -EnhancedSecurity:1 `
    -EncryptionSecurity:1 `
    -SkipDBManager:1 `
    -EncryptionPassPhrase:$encryptionPassPhrase `
    /F:Ccure9000Client `
    -VasServer:"localhost" `
    /F:CcureGoWebService `
    -LocalServiceAccount:1 `
    -VasForWebServiceLocalOrRemote:1 `
    /F:VictorWebService `
    -SqlServer:$sqlServer `
    -WebServiceDomainName:$sqlServer `
    -WebServiceUsername:$username `
    -VictorWebPort:HTTPS `
    -VictorWebPortNumber:$ccurePortalPortNumber `
    -VictorWebClientAdminUsername:$username `
    -VictorWebClientAdminPassword:$victorWebClientPassword `
    -VictorWebClientAdminPasswordReenter:$victorWebClientPassword `
    -WebServicePassword:$victorWebClientPassword `
    -vWCServer:"localhost" `
    /F:CCUREAutoUpdateServer `
    -CcureAutoUpdateInstallDate:"12/21/2024" `
    /F:victorClientAutoUpdatePackage `
    /F:CCUREAutoUpdateClient `
    /F:CCPortal `
    -CCurePortalPort:HTTPS `
    -UseHTTPSPortal:1 `
    -ServerMode:IIS `
    -IpType:true `
    -AllowRemoteConnections:true `
    -PortalServer:"localhost" `
    -WebserviceDevice:"localhost" `
    /F:VictorWebClient

# End of script






# Execute the command
& "C:\Program Files\ccure\build%5CUC_$env:CCUREBUILD\Copied\ISOImage\bin\dashboard.exe" /SOURCE:"C:\Program Files\ccure\build%5CUC_$env:CCUREBUILD\Copied\ISOImage" /F:VictorAutoUpdateServer -JCIInstallDirectory:"C:\Program Files (x86)\JCI" /F:VictorApplicationServer -SqlServer:$Env:USERDOMAIN -SQLServerPassword:P@ssw0rd -VasServiceDomainName:$Env:USERDOMAIN -VasServiceUsername:$Env:USERNAME -SQLServerUsername:sa -VasServiceAccountType:1 -IntegratedSecurity:FALSE -MicrosoftEntraID:FALSE -VasLocalServiceAccount:$Env:USERDOMAIN\$Env:USERNAME -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -IsSqlServerLocal:1 -AppServerType:0 -DBManagerExePath:"C:\Program Files (x86)\JCI\Crossfire\DBManager" -ServerType:1 -DBBuildInstallConfig:Standalone -VictorOnlyIsInstalled:0 -CCureClientIsInstalled:1 -VictorClientIsInstalled:0 -SqlConnectionString:"Data Source=$Env:USERDOMAIN;Initial Catalog=master;Integrated Security=False;User ID=sa;Password=P@ssw0rd;" -WebSiteName:"Default Web Site" -EnhancedSecurity:1 -EncryptionSecurity:1 -SkipDBManager:1 -EncryptionPassPhrase:hWRH2meXkWeEbryZeN7LWFpuaLp2mXFawLNKnamcnDU= /F:Ccure9000Client -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -VasServer:localhost /F:CcureGoWebService -LocalServiceAccount:1 -VasServer:localhost -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -WebSiteName:"Default Web Site" /F:VictorWebService -SqlServer:$Env:USERDOMAIN -SQLServerPassword:P@ssw0rd -WebServiceDomainName:$Env:USERDOMAIN -SQLServerUsername:sa -WebServiceUsername:$Env:USERNAME -VasServer:localhost -IntegratedSecurity:FALSE -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -VasForWebServiceLocalOrRemote:1 -SqlConnectionString:"Data Source=$Env:USERDOMAIN;Initial Catalog=master;Integrated Security=False;User ID=sa;Password=P@ssw0rd;" -WebSiteName:"Default Web Site" /F:CCUREAutoUpdateServer -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -CcureAutoUpdateInstallDate:12/21/2024 -WebSiteName:"Default Web Site" /F:victorClientAutoUpdatePackage /F:CCUREAutoUpdateClient -JCIInstallDirectory:"C:\Program Files (x86)\JCI" /F:CCPortal -CCurePortalPort:HTTPS -UseHTTPSPortal:1 -ServerMode:IIS -IpType:true -AllowRemoteConnections:true -CCurePortalPortNumber:443 -PortalServer:localhost -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -JCIInstallDirectory:"C:\Program Files (x86)\JCI" -WebserviceDevice:localhost -WebSiteName:"Default Web Site" /F:VictorWebClient -VictorWebPort:HTTPS -VictorWebPortNumber:443 -WebServiceUsername:$Env:USERNAME -VictorWebClientAdminUsername:$Env:USERNAME -VictorWebClientAdminPassword:UhaNA+9zcAqW48b5tm7u2w== -VictorWebClientAdminPasswordReenter:UhaNA+9zcAqW48b5tm7u2w== -WebServicePassword:UhaNA+9zcAqW48b5tm7u2w== -vWCServer:localhost -JCIInstallDirectory:"C:\Program Files (x86)\JCI" 




# Define the variable name and value
$EnvName = "CCUREBUILD"
$EnvValue = "YourValueHere"

# Add the environment variable to the registry
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name $EnvName -Value $EnvValue -Force

# Notify the system of the environment variable change
[Environment]::SetEnvironmentVariable($EnvName, $EnvValue, [System.EnvironmentVariableTarget]::Machine)

# Refresh the environment variables in the current session (optional)
$env:CCUREBUILD = $EnvValue

Write-Output "Environment variable $EnvName has been added with value: $EnvValue"






























function Execute-DashboardInstaller {
    param ()

    # Expand and clean environment variables
    $ccureBuild = $env:CCUREBUILD.Trim().Trim('"')
    $username = $env:USERNAME.Trim().Trim('"')
    $userDomain = $env:USERDOMAIN.Trim().Trim('"')

    # Construct the command path
    $command = "C:\Program Files\ccure\build%5C$ccureBuild\Copied\ISOImage\bin\dashboard.exe"

    # Define the arguments as an array
    $arguments = @(
        "/SOURCE:`"C:\Program Files\ccure\build%5C$ccureBuild\Copied\ISOImage`"",
        "/F:VictorAutoUpdateServer",
        "-JCIInstallDirectory:`"C:\Program Files (x86)\JCI`"",
        "/F:VictorApplicationServer",
        "-SqlServer:$userDomain",
        "-SQLServerPassword:P@ssw0rd",
        "-VasServiceDomainName:$userDomain",
        "-VasServiceUsername:$username",
        "-SQLServerUsername:sa",
        "-VasServiceAccountType:1",
        "-IntegratedSecurity:FALSE",
        "-MicrosoftEntraID:FALSE",
        "-VasLocalServiceAccount:$userDomain\$username",
        "-JCIInstallDirectory:`"C:\Program Files (x86)\JCI`"",
        "-IsSqlServerLocal:1",
        "-AppServerType:0",
        "-DBManagerExePath:`"C:\Program Files (x86)\JCI\Crossfire\DBManager`"",
        "-ServerType:1",
        "-DBBuildInstallConfig:Standalone",
        "-VictorOnlyIsInstalled:0",
        "-CCureClientIsInstalled:1",
        "-VictorClientIsInstalled:0",
        "-SqlConnectionString:`"Data Source=$userDomain;Initial Catalog=master;Integrated Security=False;User ID=sa;Password=P@ssw0rd;`"",
        "-WebSiteName:`"Default Web Site`"",
        "-EnhancedSecurity:1",
        "-EncryptionSecurity:1",
        "-SkipDBManager:1",
        "-EncryptionPassPhrase:hWRH2meXkWeEbryZeN7LWFpuaLp2mXFawLNKnamcnDU=",
        "/F:Ccure9000Client",
        "-JCIInstallDirectory:`"C:\Program Files (x86)\JCI`"",
        "-VasServer:localhost"
    )

    # Execute the command
    & $command @arguments
}

# Call the function
Execute-DashboardInstaller
