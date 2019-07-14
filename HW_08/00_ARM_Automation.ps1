$RGName = 'hw0008'
$location = 'westeurope'
$SAName = $RGName+'startupfolder'
$blobContainerName = $RGName
$sshRSAPublicKey = Get-Content '.\arm\linked\demo.pub' | select -First 1 | ConvertTo-SecureString -AsPlainText -Force

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}

Get-AzResourceGroup -Name $RGName -ErrorVariable notPresent -ErrorAction SilentlyContinue 

if ($notPresent) {
    New-AzResourceGroup -Name $RGName -Location $location
}

$vault = Get-AzKeyVault -VaultName "$RGName-vault"
if (-Not $vault) {
    $vault = New-AzKeyVault -Name "$RGName-vault" -ResourceGroupName $RGName -Location $location -EnabledForDeployment -EnabledForTemplateDeployment
    $subscriptionUsers = Get-AzADUser
    foreach ($user in $subscriptionUsers) {
        Set-AzKeyVaultAccessPolicy -VaultName "$RGName-vault" -ObjectId $user.id -PermissionsToSecrets Get,List,Set
    }
    if (Get-AzKeyVaultSecret -vaultName "$RGName-vault" -name "kaspassword") {
        $kaspassword = (Get-AzKeyVaultSecret -vaultName "$RGName-vault" -name "kaspassword").SecretValueText | ConvertTo-SecureString -AsPlainText -Force
    } else {
        $kaspassword = Read-Host "Enter principalAppPassword" -AsSecureString
        Set-AzKeyVaultSecret -VaultName "$RGName-vault" -Name 'kaspassword' -SecretValue $kaspassword
    }
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

if (-not (Get-AzADApplication -DisplayName $RGName"KuberCluster")) {
    $app = New-AzADApplication -DisplayName $RGName"KuberCluster" -IdentifierUris $RGName"KuberCluster" -Password $kaspassword
    New-AzADServicePrincipal -ApplicationId $app.ApplicationId 
    start-sleep 15
    New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $app.ApplicationId
    start-sleep 15
} else {
    $app = Get-AzADApplication -DisplayName $RGName"KuberCluster"
}

New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile '.\arm\Main.json' -SASToken $token -RGName $RGName -SAName $SAName -sshRSAPublicKey $sshRSAPublicKey -servicePrincipalClientId $app.ApplicationId -kaspassword $kaspassword
$lastDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $RGName | Sort Timestamp -Descending | Select -First 1
$env:AKR_HOST = $lastDeployment.Outputs['acrLoginServer'].Value
$env:AKR_USERNAME = $app.ApplicationId
$env:AKR_PASSWORD = (Get-AzKeyVaultSecret -vaultName $RGName'-vault' -name 'kaspassword').SecretValueText
$env:RG_NAME = $RGName
$env:AKS_CLUSTERNAME = $lastDeployment.Outputs['aksName'].Value
write-host "please run from console: az aks get-credentials  --resource-group  $($RGname) --name '$($env:AKS_CLUSTERNAME)'"
write-host "please run from console: kubectl create secret docker-registry acr-auth --docker-server '$($env:AKR_HOST)' --docker-username '$($env:AKR_USERNAME)' --docker-password '$($env:AKR_PASSWORD)' --docker-email 'salvador@list.ru'"