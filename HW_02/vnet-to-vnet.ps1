#Connect-AzAccount

$Location1 = "West Europe"
$Location2 = "North Europe"

$VNetName1 = "West_Europe_VMNET01_"
$VNetName2 = "North_Europe_VMNET02_"

$RG1 = "Resource_Group_01_in_WE"
$RG2 = "Resource_Group_02_in_NE"

$FESubName1 = "FrontEndW01"
$BESubName1 = "Backend"
$GWSubName1 = "GatewaySubnet"
$FESubName2 = "FrontEnd"
$BESubName2 = "Backend"
$GWSubName2 = "GatewaySubnet"

$VNetPrefix11 = "10.11.0.0/16"
$VNetPrefix12 = "10.12.0.0/16"
$FESubPrefix1 = "10.11.3.0/24"
$BESubPrefix1 = "10.12.4.0/24"
$GWSubPrefix1 = "10.12.255.0/27"

$VNetPrefix21 = "10.21.0.0/16"
$VNetPrefix22 = "10.22.0.0/16"
$FESubPrefix2 = "10.21.3.0/24"
$BESubPrefix2 = "10.22.4.0/24"
$GWSubPrefix2 = "10.22.255.0/27"

$GWName1 = "VNet1GW"
$GWIPName1 = "VNet1GWIP"
$GWIPconfName1 = "gwipconf1"
$Connection12 = "VNet1toVNet2"

$GWName2 = "VNet2GW"
$GWIPName2 = "VNet2GWIP"
$GWIPconfName2 = "gwipconf2"
$Connection21 = "VNet2toVNet1"



$azSubscriptions = Get-AzSubscription
$azSubscriptionsCounter = 0
if (!$azSubscriptions) {
    Write-Output "You have no active subscriptions"
    exit
} 
Write-Output "You have next subscriptions"
foreach ($sub in $azSubscriptions) {
    $azSubscriptionsCounter++
    $subName = $sub.Name
    Write-Output "$azSubscriptionsCounter) $subName"
}
$azSubscriptionSelect = Read-Host -Prompt 'Input your subscription number'
if ((!$azSubscriptionSelect -match "^\d+$" ) -Or ($azSubscriptionSelect -gt $azSubscriptions.Count)) {
    Write-Output "Wrong input, please try again"
    exit
} else {
    Select-AzSubscription -SubscriptionName $azSubscriptions[$azSubscriptionSelect-1].Name
}
New-AzResourceGroup -Name $RG1 -Location $Location1
$fesub1 = New-AzVirtualNetworkSubnetConfig -Name $FESubName1 -AddressPrefix $FESubPrefix1
$besub1 = New-AzVirtualNetworkSubnetConfig -Name $BESubName1 -AddressPrefix $BESubPrefix1
$gwsub1 = New-AzVirtualNetworkSubnetConfig -Name $GWSubName1 -AddressPrefix $GWSubPrefix1

New-AzVirtualNetwork -Name $VNetName1 -ResourceGroupName $RG1 -Location $Location1 -AddressPrefix $VNetPrefix11,$VNetPrefix12 -Subnet $fesub1,$besub1,$gwsub1

$gwpip1 = New-AzPublicIpAddress -Name $GWIPName1 -ResourceGroupName $RG1 -Location $Location1 -AllocationMethod Dynamic

$vnet1 = Get-AzVirtualNetwork -Name $VNetName1 -ResourceGroupName $RG1
$subnet1 = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet1
$gwipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName1 -Subnet $subnet1 -PublicIpAddress $gwpip1

New-AzVirtualNetworkGateway -Name $GWName1 -ResourceGroupName $RG1 -Location $Location1 -IpConfigurations $gwipconf1 -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1

New-AzResourceGroup -Name $RG2 -Location $Location2
$fesub2 = New-AzVirtualNetworkSubnetConfig -Name $FESubName2 -AddressPrefix $FESubPrefix2
$besub2 = New-AzVirtualNetworkSubnetConfig -Name $BESubName2 -AddressPrefix $BESubPrefix2
$gwsub2 = New-AzVirtualNetworkSubnetConfig -Name $GWSubName2 -AddressPrefix $GWSubPrefix2

New-AzVirtualNetwork -Name $VnetName2 -ResourceGroupName $RG2 `
-Location $Location2 -AddressPrefix $VnetPrefix21,$VnetPrefix22 -Subnet $fesub2,$besub2,$gwsub2

$gwpip2 = New-AzPublicIpAddress -Name $GWIPName2 -ResourceGroupName $RG2 `
-Location $Location2 -AllocationMethod Dynamic

$vnet2 = Get-AzVirtualNetwork -Name $VnetName2 -ResourceGroupName $RG2
$subnet2 = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet2
$gwipconf2 = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName2 -Subnet $subnet2 -PublicIpAddress $gwpip2

New-AzVirtualNetworkGateway -Name $GWName2 -ResourceGroupName $RG2 -Location $Location2 -IpConfigurations $gwipconf2 -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1

$vnet1gw = Get-AzVirtualNetworkGateway -Name $GWName1 -ResourceGroupName $RG1
$vnet2gw = Get-AzVirtualNetworkGateway -Name $GWName2 -ResourceGroupName $RG2

New-AzVirtualNetworkGatewayConnection -Name $Connection12 -ResourceGroupName $RG1 -VirtualNetworkGateway1 $vnet1gw -VirtualNetworkGateway2 $vnet2gw -Location $Location1 -ConnectionType Vnet2Vnet -SharedKey 'AzureA1b2C3'

New-AzVirtualNetworkGatewayConnection -Name $Connection21 -ResourceGroupName $RG2 -VirtualNetworkGateway1 $vnet2gw -VirtualNetworkGateway2 $vnet1gw -Location $Location2 -ConnectionType Vnet2Vnet -SharedKey 'AzureA1b2C3'

$connectionAZ12 = Get-AzVirtualNetworkGatewayConnection -Name $Connection12 -ResourceGroupName $RG1 
$connectionAZ12Status = $connectionAZ12.connectionStatus

Write-Output "Your connection status is: $connectionAZ12Status"