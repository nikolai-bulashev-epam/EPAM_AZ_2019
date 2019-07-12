$RGName = 'hw08'
$location = 'westeurope'
$SAName = $RGName+'startupfolder'
$blobContainerName = $RGName
$sshRSAPublicKey = Get-Content '..\..\DemoKey\demo.pub' | select -First 1 | ConvertTo-SecureString -AsPlainText -Force

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

if (Get-AzADApplication -DisplayName $RGName"KuberCluster") {
    Remove-AzADApplication -DisplayName $RGName"KuberCluster"
}

$kaspassword = Read-Host "Enter principalAppPassword" -AsSecureString
$app = New-AzADApplication -DisplayName $RGName"KuberCluster" -IdentifierUris $RGName"KuberCluster" -Password $pppassword
New-AzADServicePrincipal -ApplicationId $app.ApplicationId 
start-sleep 15
New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $app.ApplicationId
start-sleep 15
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SASToken $token -RGName $RGName -SAName $SAName -sshRSAPublicKey $sshRSAPublicKey -servicePrincipalClientId $app.ApplicationId -kaspassword $kaspassword