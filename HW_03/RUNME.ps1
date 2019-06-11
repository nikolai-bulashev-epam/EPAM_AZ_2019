$RGName = 'hw03'
$location = 'westeurope'
$SAName = 'hw03startupfolder'
$SAShareName = $RGName
Get-AzResourceGroup -Name $RGName -ErrorVariable notPresent -ErrorAction SilentlyContinue

if ($notPresent) {
    New-AzResourceGroup -Name $RGName -Location $location
}

$storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresentBucket -ErrorAction SilentlyContinue
if ($notPresentBucket) {
    $storageAcct = New-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -Location $location -SkuName Standard_RAGRS -Kind StorageV2
    $share = New-AzStorageShare -Name $SAShareName -Context $storageAcct.Context
} else {
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    $share = Get-AzStorageShare -Name $SAShareName -Context $storageAcct.Context
}

$token = New-AzStorageAccountSASToken -ResourceType Service,Container,Object -Service Blob,File,Table,Queue -Permission "ral" -context $storageAcct.Context

#$token = New-AzStorageContainerSASToken -Name "Test" -Permission rwdl
$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File
foreach($file in $files)
{
    $localFile = $localFileDirectory+$file
    Set-AzStorageFileContent  -Share $share -Source $localFile -Force
}
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -containerSasToken $token -SAName $SAName -RGName $RGName 