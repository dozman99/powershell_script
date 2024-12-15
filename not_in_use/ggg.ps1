$folder = “C:\SQLServerDownload”
$url= https://download.microsoft.com/download/D/0/C/D0CCEE78-05BE-4A5E-AE9C-2FDE69F6600D/SQLServerVnextCTP2-x64-ENU.iso
$req = [System.Net.HttpWebRequest]::Create($url)
$req.Method = “HEAD”
$response = $req.GetResponse()
$fUri = $response.ResponseUri
$filename = [System.IO.Path]::GetFileName($fUri.LocalPath);
$response.Close()
$target = join-path $folder $filename
Invoke-WebRequest -Uri $url -OutFile $target

$folder = “C:\SQLServerDownload”
$url= https://download.microsoft.com/download/D/0/C/D0CCEE78-05BE-4A5E-AE9C-2FDE69F6600D/SQLServerVnextCTP2-x64-ENU.iso
$req = [System.Net.HttpWebRequest]::Create($url)
$req.Method = “HEAD”
$response = $req.GetResponse()
$fUri = $response.ResponseUri
$filename = [System.IO.Path]::GetFileName($fUri.LocalPath);
$response.Close()
$target = join-path $folder $filename
Invoke-WebRequest -Uri $url -OutFile $target

$ImagePath = ‘C:\SQLServerDownload\SQLServerVnextCTP2-x64-ENU.iso’
New-Item -Path C:\SQLServer -ItemType Directory
Copy-Item -Path (Join-Path -Path (Get-PSDrive -Name ((Mount-DiskImage -ImagePath $ImagePath -PassThru) | Get-Volume).DriveLetter).Root -ChildPath ‘*’) -Destination C:\SQLServer\ -Recurse
Dismount-DiskImage -ImagePath $ImagePath

Get-PackageProvider -Name NuGet –ForceBootstrap

Install-Module -Name SqlServerDsc -Force


Configuration SQLServerConfiguration
{
Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName SqlServerDsc
node localhost
{
WindowsFeature ‘NetFramework45’ {
Name   = ‘NET-Framework-45-Core’
Ensure = ‘Present’
}
SqlSetup ‘InstallDefaultInstance’
{
InstanceName        = ‘ MSSQLSERVER’
Features            = ‘SQLENGINE’
SourcePath          = ‘C:\ SQLServer’
SQLSysAdminAccounts = @(‘Administrators’)
DependsOn           = ‘[WindowsFeature]NetFramework45’
}
}
}
SQLServerConfiguration