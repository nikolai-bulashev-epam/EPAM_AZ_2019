$RGName = 'hw06'
$location = 'westeurope'
$SAName = $RGName+'startupfolder'
$blobContainerName = $RGName
$dbsuffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | % {[char]$_})
$dbstart = 'AdventureWorksLT'
$dbmask = new-object System.String("AdventureWorksLT*")
$dbname = $dbstart+$dbsuffix;

function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Scramble-String([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}
$vname = $RGname+"vault"
$vault = Get-AzKeyVault -VaultName $vname -ErrorVariable notPresentVault -ErrorAction SilentlyContinue
if (-not $vault) {
    $password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacters -length 5 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 2 -characters '1234567890'
    $password += Get-RandomCharacters -length 2 -characters '!=@#'
    $password = Scramble-String $password
    Write-Host "Your password is: $password" -ForegroundColor Green
    $SQLsecureStringPswd = ConvertTo-SecureString $password -AsPlainText -Force
} else {
    $password = (Get-AzKeyVaultSecret -vaultName "hw06vault" -name "sql01password").SecretValueText
    Write-Host "You can use old password: $password" -ForegroundColor Green
    $SQLsecureStringPswd = ConvertTo-SecureString $password -AsPlainText -Force 
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

$azdb = Get-AzSqlDatabase -ServerName "sqlserver$RGName" -ResourceGroupName $RGName -DatabaseName "AdventureWorks*" -ErrorVariable nodbIsPresent -ErrorAction SilentlyContinue
if ($azdb) {
   Remove-AzSqlDatabase -DatabaseName $azdb.DatabaseName -ResourceGroupName $azdb.ResourceGroupName -ServerName $azdb.ServerName
   Write-Host "Database will be deleted for redeploy" -ForegroundColor Yellow
}
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SASToken $token -RGName $RGName -SAName $SAName -TemplateParameterFile 'parameters.json' -sqlpassword $SQLsecureStringPswd -databaseName $dbname
$lastDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $RGName | Sort Timestamp -Descending | Select -First 1
if ($lastDeployment.ProvisioningState -eq 'Succeeded') {
    Write-Host "-----------------------------------" -ForegroundColor Green
    Write-Host 'Deployment was succeeded!' -ForegroundColor Green
    $appURL = $lastDeployment.Outputs['trafficManagerFqdn'].Value 
    Write-Host "Please visit $appURL to check application functionallity" -ForegroundColor Green
    $ssdeURL = $lastDeployment.Outputs['sqlServerFqdn'].Value
    Write-Host "sql server fqdn is $ssdeURL" -ForegroundColor Green
    Write-Host "sql server login is sqladmin" -ForegroundColor Green
    Write-Host "sql server password is $password" -ForegroundColor Green
    Write-Host "-----------------------------------"
} else {
    Write-Host "-----------------------------------" -ForegroundColor Yellow
    Write-Host 'Deployment was UNsucceeded!' -ForegroundColor Yellow
    Write-Host "-----------------------------------"
}