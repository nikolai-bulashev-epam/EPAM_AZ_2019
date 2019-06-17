Configuration OpenPort
{
    Install-Module -Name xNetworking
    Import-DscResource -ModuleName xNetworking

    xFirewall open8080port
    {
        Name        = 'HW048080TCP'
        DisplayName = '8080 tcp in HW04'
        Action      = 'Allow'
        Direction   = 'Inbound'
        LocalPort   = ('8080')
        Protocol    = 'TCP'
        Profile     = 'Any'
        Enabled     = 'True'
    }
}
