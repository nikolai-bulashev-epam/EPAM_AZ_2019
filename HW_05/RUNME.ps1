$RGName = 'hw05'
$location = 'westeurope'
$anotherlocation = 'japanwest'
$SAName = $RGName+'startupfolder'
$blobContainerName = $RGName
Get-AzResourceGroup -Name $RGName -ErrorVariable notPresent -ErrorAction SilentlyContinue

if ($notPresent) {
    New-AzResourceGroup -Name $RGName -Location $location
}

$storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresentBucket -ErrorAction SilentlyContinue
if ($notPresentBucket) {
    Write-Host 'notPresent'
    $storageAcct = New-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -Location $location -SkuName Standard_RAGRS -Kind StorageV2
    new-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context
} else {
    Write-Host 'Present'
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    Get-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context
}

$token = New-AzStorageContainerSASToken -Name  $blobContainerName -Permission rwdl -ExpiryTime (Get-Date).AddMinutes(30.0) -context $storageAcct.Context 

$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File -Recurse
foreach($file in $files)
{
    Write-Host $file
    set-AzStorageblobcontent  -File $file.FullName -Force -Container $blobContainerName -blob $file -Context $storageAcct.Context 
}
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SASToken $token -RGName $RGName -SAName $SAName -TemplateParameterFile 'parameters.json'