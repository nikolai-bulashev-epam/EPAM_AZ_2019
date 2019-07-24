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


$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 1 -characters '1234567890'
$password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'
 
 
$password = Scramble-String $password
Write-Host "Your password is: $password" -ForegroundColor Green
$secureStringPswd = ConvertTo-SecureString $password -AsPlainText -Force

$RGName = 'hw09'
$location = 'westeurope'
$SAName = 'hw09startupfolder'
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

Install-Module -Name xPSDesiredStateConfiguration -Scope CurrentUser
$token = New-AzStorageContainerSASToken -Name  $blobContainerName -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0) -context $storageAcct.Context 
$dscCompilationJobId = [System.Guid]::NewGuid().toString()
$tenantId = Get-AzSubscription | Select-Object tenantid
$appname = $RGName+"AppAutomation"
if (-not (Get-AzADApplication -DisplayName $appname)) {
    $app = New-AzADApplication -DisplayName $appname -IdentifierUris $appname -Password $secureStringPswd
    New-AzADServicePrincipal -ApplicationId $app.ApplicationId 
    start-sleep 15
    New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $app.ApplicationId
    start-sleep 15
} else {
    $app = Get-AzADApplication -DisplayName $appname
    Remove-AzADAppCredential -ApplicationId $app.ApplicationId
    New-AzADAppCredential -ApplicationId $app.ApplicationId -Password $secureStringPswd -EndDate (Get-Date).AddDays(30)
}

$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File -Recurse
foreach($file in $files)
{
    Write-Host $file
    set-AzStorageblobcontent  -File $file.FullName -Force -Container $blobContainerName -blob $file -Context $storageAcct.Context 
}
New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -SAName $SAName -RGName $RGName -Mode Incremental -Verbose -SASToken $token -VMpassword $secureStringPswd -jobid $dscCompilationJobId -tenantid $tenantId.TenantId -appid $app.ApplicationId.Guid