Function GetFiles {
    Write-Host -ForegroundColor Green "Listing directories and files with sizes, creation date, and last modified date in MB.."       # Get the storage account context
    $ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context       # Create an array to store file details
    $fileDetails = @()       # List directories
    $directories = Get-AZStorageFile -Context $ctx -ShareName $fileShareName       # Loop through directories
    foreach ($directory in $directories) {
        Write-Host -ForegroundColor Magenta "Processing Directory: $($directory.Name)"           # Output details for debugging
        $directory | Format-List           # Skip if directory URI is null
        if ($directory.Uri -eq $null) {
            Write-Host -ForegroundColor Yellow "Warning: Directory URI is null. Skipping Directory: $($directory.Name)"
            continue
        }           # HEAD request to get file properties
        try {
            $directoryProperties = Invoke-RestMethod -Method Head -Uri $directory.Uri -Headers @{
                "x-ms-version" = "2019-02-02"
                "Authorization" = "Bearer $($ctx.Token)"
            }
        }
        catch {
            Write-Host -ForegroundColor Red "Error retrieving directory properties. Directory Name: $($directory.Name)"
            Write-Host "Error details: $"
            continue
        }           # Add directory details to the array
        $directoryDetails = [PSCustomObject]@{
            DirectoryName = $directory.Name
            FileName = $null  # Placeholder for files
            Size_MB = $null   # Placeholder for file size in MB
            CreationDate = $directoryProperties.'x-ms-file-creation-time'  # Added creation date property
        }           $fileDetails += $directoryDetails           # List files in the current directory
        $files = Get-AZStorageFile -Context $ctx -ShareName $fileShareName -Path $directory.Name | Get-AZStorageFile           # Loop through files
        foreach ($file in $files) {
            Write-Host -ForegroundColor Cyan "Processing File: $($file.Name)"               # Output details for debugging
            $file | Format-List               # Skip if file URI is null
            if ($file.Uri -eq $null) {
                Write-Host -ForegroundColor Yellow "Warning: File URI is null. Skipping File: $($file.Name)"
                continue
            }               # HEAD request to get file properties
            try {
                $fileProperties = Invoke-RestMethod -Method Head -Uri $file.Uri -Headers @{
                    "x-ms-version" = "2019-02-02"
                    "Authorization" = "Bearer $($ctx.Token)"
                }
            }
            catch {
                Write-Host -ForegroundColor Red "Error retrieving file properties. File Name: $($file.Name)"
                Write-Host "Error details: $"
                continue
            }               # Convert size to MB
            $sizeInMB = [math]::Round($file.Length / 1MB, 2)               # Add file details to the array
            $fileDetails += [PSCustomObject]@{
                DirectoryName = $directory.Name
                FileName = $file.Name
                Size_MB = $sizeInMB
                LastModified = $fileProperties.'x-ms-file-last-write-time'  # Added last modified date property
            }
        }
    }       # Get the current date in the specified format
    $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"       # Specify the new export path with file share name and current date with time as the suffix
    $exportPath = "C:\Users\Niket kumar Singh\Downloads\lnt$fileShareName_$currentDateTime.xlsx"       # Export to Excel
    $fileDetails | Export-Excel -Path $exportPath -AutoSize -Show       Write-Host "Excel exported to: $exportPath"
}  













Function GetFiles {
    Write-Host -ForegroundColor Green "Listing directories and files with sizes in MB.."
    # Get the storage account context
    $ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context
    # Create an array to store file details
    $fileDetails = @()
    # List directories
    $directories = Get-AZStorageFile -Context $ctx -ShareName $fileShareName
    # Loop through directories
    foreach ($directory in $directories) {
        Write-Host -ForegroundColor Magenta "Directory Name: $($directory.Name)"
        # Add directory details to the array
        $fileDetails += [PSCustomObject]@{
            DirectoryName = $directory.Name
            FileName = $null  # Placeholder for files
            Size_MB = $null   # Placeholder for file size in MB
        }
        # List files in the current directory
        $files = Get-AZStorageFile -Context $ctx -ShareName $fileShareName -Path $directory.Name | Get-AZStorageFile
        # Loop through files
        foreach ($file in $files) {
            # Convert size to MB
            $sizeInMB = [math]::Round($file.Length / 1MB, 2)
            # Add file details to the array
            $fileDetails += [PSCustomObject]@{
                DirectoryName = $directory.Name
                FileName = $file.Name
                Size_MB = $sizeInMB
            }
        }
    }
    # Get the current date in the specified format
    $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"
    # Specify the new export path with file share name and current date with time as the suffix
    $exportPath = "C:\Users\Niket kumar Singh\Downloads\lnt$fileShareName_$currentDateTime.xlsx"
    # Export to Excel
    $fileDetails | Export-Excel -Path $exportPath -AutoSize -Show
    Write-Host "Excel exported to: $exportPath"
}
