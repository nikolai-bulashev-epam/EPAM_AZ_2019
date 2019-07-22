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

$RGName = 'hw092'
$location = 'westeurope'
$SAName = 'hw092startupfolder'
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
Publish-AzVMDscConfiguration ".\dsc\iis.ps1" -OutputArchivePath ".\DSC\iis.zip" -Force
$token = New-AzStorageContainerSASToken -Name  $blobContainerName -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0) -context $storageAcct.Context 
$tenantId = Get-AzSubscription | Select-Object tenantid
$UTCNow = (Get-Date).ToUniversalTime()
$UTCTimeTick = $UTCNow.Ticks.tostring()
$appname = $RGName+"AppAutomation"
if (-not (Get-AzADApplication -DisplayName $appname)) {
    $app = New-AzADApplication -DisplayName $appname -IdentifierUris $appname -Password $secureStringPswd
    New-AzADServicePrincipal -ApplicationId $app.ApplicationId 
    start-sleep 15
    New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $app.ApplicationId
    start-sleep 15
} else {
    $app = Get-AzADApplication -DisplayName $appname
    Remove-AzADAppCredential -ApplicationId $app.ApplicationId -Force
    New-AzADAppCredential -ApplicationId $app.ApplicationId -Password $secureStringPswd -EndDate (Get-Date).AddDays(30)
}

$localFileDirectory = '.\'
$files = Get-ChildItem -Path $localFileDirectory -File -Recurse
foreach($file in $files)
{
    Write-Host $file
    set-AzStorageblobcontent  -File $file.FullName -Force -Container $blobContainerName -blob $file -Context $storageAcct.Context 
}
$parameters = @{}
$parameters.Add('SAName',$SAName) 
$parameters.Add('VMpassword',$secureStringPswd)
$parameters.Add('CurrentDateTimeInTicks',$UTCTimeTick)
$parameters.Add('tenantid',$tenantId.TenantId)
$parameters.Add('appid',$app.ApplicationId.Guid)

New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateFile 'Main.json' -TemplateParameterObject $parameters -SAStoken $token