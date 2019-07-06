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
$lastDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $RGName | Sort Timestamp -Descending | Select -First 1

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
$vault = Get-AzRecoveryServicesVault -Name $lastDeployment.Outputs['RSVaultName'].value
if ($vault) {
    Set-AzRecoveryServicesVaultContext -Vault $vault
    
    $backupcontainer = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName $lastDeployment.Outputs['vmname'].value
    $item = Get-AzRecoveryServicesBackupItem -Container $backupcontainer -WorkloadType "AzureVM"
    $statusTable = Get-AzRecoveryservicesBackupJob
    if (@($statusTable | Where-Object {$_.Status -eq "InProgress"}).Count) {
        Backup-AzRecoveryServicesBackupItem -Item $item
    } else {
        write-host "Some backup job already in progress. New job not would not be started"
        $statusTable
    }
    
    $status = 1
    while($status) {
        $statusTable = Get-AzRecoveryservicesBackupJob
        $status = @($statusTable | Where-Object {$_.Status -eq "InProgress"}).Count
        if ($status) {
            Write-Host "Backup is still running. Waiting more 15 secs"
            Start-Sleep -Seconds 15
        }
    }
    Write-Host "Backup finished"
} else {
    Write-Host "Recovery Service Vault not found, exiting"
    exit 1
}
Write-Host "Lets recover VM disks"
$namedContainer = Get-AzRecoveryServicesBackupContainer  -ContainerType "AzureVM" -Status "Registered" -FriendlyName $lastDeployment.Outputs['vmname'].value
$backupitem = Get-AzRecoveryServicesBackupItem -Container $namedContainer -WorkloadType "AzureVM"
if ($backupitem) {
    Write-Host "Some recovery points found"
    $startDate = (Get-Date).AddDays(-7)
    $endDate = Get-Date
    $rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $backupitem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime()
    $restorejob = Restore-AzRecoveryServicesBackupItem -RecoveryPoint $rp[0] -StorageAccountName $lastDeployment.Outputs['saname'].value -StorageAccountResourceGroupName $RGName
    Wait-AzRecoveryServicesBackupJob -Job $restorejob -Timeout 43200
    Write-Host "restoring disks finished"
    Write-Host "Starting VM recover"
    $restorejob = Get-AzRecoveryServicesBackupJob -Job $restorejob
    $details = Get-AzRecoveryServicesBackupJobDetails -Job $restorejob
    $properties = $details.properties
    $templateBlobURI = $properties["Template Blob Uri"]
    $recoveryStorageAcct = Get-AzStorageAccount -ResourceGroupName $RGName -Name $properties['Target Storage Account Name']
    Get-AzStorageContainer -Context $recoveryStorageAcct.Context -name $properties['Config Blob Container Name'] | Set-AzStorageContainerAcl -Permission Blob -PassThru
    $destination_path = "~\vmconfig.json"
    Get-AzStorageBlobContent -Container $properties["Config Blob Container Name"] -Blob $properties["Config Blob Name"] -Context $recoveryStorageAcct.Context -Destination "~\vmconfig.json"
    $obj = ((Get-Content -Path $destination_path -Raw -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json
    $osdiskconfig = New-AzDiskConfig -AccountType Standard_LRS -OsType Windows -Location $location -CreateOption import -SourceUri $obj.'properties.storageProfile'.osDisk.vhd.uri
    New-AzDisk -ResourceGroupName $RGname -name $obj.'properties.storageProfile'.osDisk.name -Disk $osdiskconfig
    foreach ($dd in $obj.'properties.storageProfile'.dataDisks) {
        $datadiskconfig = New-AzDiskConfig -AccountType Standard_LRS -OsType Windows -Location $location -CreateOption import -SourceUri $dd.vhd.uri
        New-AzDisk -ResourceGroupName $RGname -name $dd.name -Disk $datadiskconfig
    }
    New-AzResourceGroupDeployment -Name VMRecovery -ResourceGroupName $RGName -TemplateUri $templateBlobURI -VirtualMachineName "RecoveredVM"
} else {
    Write-Host "Recovery point not found, exiting"
    exit 1
}