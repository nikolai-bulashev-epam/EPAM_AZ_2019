$RGName = 'hw04'
$location = 'westeurope'
$SAName = 'hw04startupfolder'
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

Write-Host $token
$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File -Recurse | Select-Object -ExpandProperty Fullname
foreach($file in $files)
{
    Set-AzStorageFileContent  -Share $share -Source $file -Force
}
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -containerSasToken $token -SAName $SAName -RGName $RGName 