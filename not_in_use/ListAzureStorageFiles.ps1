[CmdletBinding(SupportsShouldProcess = $true)]
Param (
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String] $sourceAzureSubscriptionId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String] $sourceStorageAccountName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String] $sourceStorageFileShareName
)

#! Functions
# Function to list sub-directories to recursively get all files and directories
function list_subdir([Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageFileDirectory]$dirs) {
    
    # Store directory path in a variable
    $path = $dirs.ShareDirectoryClient.Path
    # Store share name in a variable
    $shareName = $dirs.ShareDirectoryClient.ShareName
    # Get all files/sub-directories in the directory and store as an array in a variable
    $filesAndDirs = Get-AzStorageFile -ShareName "$shareName" -Path "$path" -Context $sourceContext | Get-AzStorageFile
    
    # Iterate through all files/sub-directories in the $fileAndDirs variable with array data type
    foreach ($f in $filesAndDirs) {

        $f | ConvertTo-Json | Out-File -FilePath ./$($f.Name).json

        if ($f.gettype().name -eq "AzureStorageFile") {
            $filePath = $($f.ShareFileClient.Path)
            $shareName = $($f.ShareFileClient.ShareName)
            $storageAccountName = $($f.ShareFileClient.AccountName)
            $sourceFile = "https://$StorageAccountName.file.core.windows.net/$shareName/$($filePath)$($sourceShareSASURI)"
            Write-Host "File Path: $filePath" -ForegroundColor Blue
            Write-Host "Source File: $sourceFile" -ForegroundColor Blue
            Write-Output ""
        }
        elseif ($f.gettype().name -eq "AzureStorageFileDirectory") {
            $directoryName = $($f.ShareDirectoryClient.Name)
            $dirShareName = $($f.ShareDirectoryClient.ShareName)
            Write-Host "Directory Name: $directoryName" -ForegroundColor Red
            Write-Host "Directory Share Name: $dirShareName" -ForegroundColor Red
            Write-Output ""
            # Call the list_subdir function to recursively get all files and directories in the directory
            list_subdir($f)

        }

    }

}

#! VARIABLE DECLARATIONS
#! Setup identity context for the subscription
# Prevent the inheritance of an AzContext from the current process
Disable-AzContextAutosave -Scope Process
# Connect to Azure with the system-assigned managed identity that represents the Automation Account
Connect-AzAccount -Identity 
# Set the Azure Subscription context using Azure Subsciption ID
Set-AzContext -SubscriptionId "$sourceAzureSubscriptionId"

# Get Storage Account Resource Group
$sourceStorageAccountRG = (Get-AzResource -Name "$sourceStorageAccountName").ResourceGroupName
# Get the primary Azure Storage Account Key from the source storage account
$sourceStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $sourceStorageAccountRG -Name $sourceStorageAccountName).Value[0]
# Create a new Azure Storage Context for the source storage account, which is required for Az.Storage Cmdlets
$sourceContext = New-AzStorageContext -StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceStorageAccountKey
# Get all Azure Files shares using the Storage Context and save as an array in a variable
$shares = Get-AzStorageShare -Context $sourceContext | Where-Object { $_.Name -eq $sourceStorageFileShareName }
# Generate source file share SAS URI Token with read, delete, and list permission w/ an expiration of 1 day
$sourceShareSASURI = New-AzStorageAccountSASToken -Context $sourceContext `
    -Service File -ResourceType Service, Container, Object -ExpiryTime(get-date).AddDays(1) -Permission "rdl"
# Iterate through all Azure Files shares in the $shares variable with array data type
$shareName = $($shares.Name)
    
# Get all the files and directories in a file share and save as an array in a variable 
$filesAndDirs = Get-AzStorageFile -ShareName $shareName -Context $sourceContext

# Iterate through all files and directories in the $filesAndDirs variable with array data type
foreach ($f in $filesAndDirs) {

    $f | ConvertTo-Json | Out-File -FilePath ./$($f.Name).json
        
    # If the $f is a file, then compare filedate to olddate and operate on old files, Else if $f is a directory, then recursively call the list_subdir function
        if ($f.GetType().Name -eq "AzureStorageFile") {
            $filePath = $($f.ShareFileClient.Path)
            $shareName = $($f.ShareFileClient.ShareName)
            $storageAccountName = $($f.ShareFileClient.AccountName)
            $sourceFile = "https://$StorageAccountName.file.core.windows.net/$shareName/$($filePath)$($sourceShareSASURI)"
            Write-Host "File Path: $filePath" -ForegroundColor Blue
            Write-Host "Source File: $sourceFile" -ForegroundColor Blue
            Write-Output ""
        }
        elseif ($f.GetType().Name -eq "AzureStorageFileDirectory") {
            $directoryName = $($f.ShareDirectoryClient.Name)
            $dirShareName = $($f.ShareDirectoryClient.ShareName)
            Write-Host "Directory Name: $directoryName" -ForegroundColor Red
            Write-Host "Directory Share Name: $dirShareName" -ForegroundColor Red
            Write-Output ""
            # Call the list_subdir function to recursively get all files and directories in the directory
            list_subdir($f)
            
        }

        # Create new line spacing in output
        Write-Output ""

    }