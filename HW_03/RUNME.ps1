$RGName = 'hw03'
$location = 'westeurope'
$SAName = 'hw03startupfolder'
$blobContainerName = $RGName
Get-AzResourceGroup -Name $RGName -ErrorVariable notPresent -ErrorAction SilentlyContinue

if ($notPresent) {
    New-AzResourceGroup -Name $RGName -Location $location
}

$storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresentBucket -ErrorAction SilentlyContinue
if ($notPresentBucket) {
    Write-Host 'notPresent'
    $storageAcct = New-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -Location $location -SkuName Standard_RAGRS -Kind StorageV2
    new-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context  -Permission blob
} else {
    Write-Host 'Present'
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    Get-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context
}
#$token = New-AzureStorageAccountSASToken -ResourceType Service,Container,Object -Service file -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0) -context $storageAcct.Context

$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File
foreach($file in $files)
{
    $localFile = $localFileDirectory+$file
    set-AzStorageblobcontent  -File $localFile -Force -Container $blobContainerName -blob $file -Context $storageAcct.Context 
}

New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SAName $SAName -RGName $RGName