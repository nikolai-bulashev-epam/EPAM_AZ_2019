$RGName = 'hw07'
$location = 'westeurope'
$SAName = $RGName+'startupfolder'
$blobContainerName = $RGName
$vm01pass = Read-Host "Enter Password" -AsSecureString

Get-AzResourceGroup -Name $RGName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    New-AzResourceGroup -Name $RGName -Location $location
}

$storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresentBucket -ErrorAction SilentlyContinue
if (-Not $storageAcct) {
    Write-Host 'notPresent'
    $storageAcct = New-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -Location $location -SkuName Standard_RAGRS -Kind StorageV2
    new-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context
} else {
    Write-Host 'Present'
    $storageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $SAName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    Get-AzStoragecontainer -Name $blobContainerName -Context $storageAcct.Context
}

$vault = Get-AzKeyVault -VaultName "$RGName-vault"
if (-Not $vault) {
    $vault = New-AzKeyVault -Name "$RGName-vault" -ResourceGroupName $RGName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment
    $subscriptionUsers = Get-AzADUser
    foreach ($user in $subscriptionUsers) {
        Set-AzKeyVaultAccessPolicy -VaultName "$RGName-vault" -ObjectId $user.id -PermissionsToSecrets Get,List,Set
    }
}
Set-AzKeyVaultSecret -VaultName "$RGName-vault" -Name 'vm01password' -SecretValue $vm01pass

$token = New-AzStorageContainerSASToken -Name  $blobContainerName -Permission rwdl -ExpiryTime (Get-Date).AddMinutes(30.0) -context $storageAcct.Context 

$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File -Recurse
foreach($file in $files)
{
    Write-Host $file
    set-AzStorageblobcontent  -File $file.FullName -Force -Container $blobContainerName -blob $file -Context $storageAcct.Context 
}
$fc = $files.count
Write-Host "Startup folder is charged by $fc files" -ForegroundColor Green

New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SASToken $token -RGName $RGName -SAName $SAName -VaultID $vault.ResourceId
