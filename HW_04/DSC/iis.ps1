Configuration ContosoWebsite
{
  param 
  (
      [String]
      $MachineName,
      
      [String]
      $indexFileUrl
  )

  Import-DscResource -ModuleName PsDesiredStateConfiguration
  Import-DscResource -ModuleName xWebAdministration
  Import-DscResource -ModuleName xNetworking
  Import-DscResource -ModuleName FileContentDsc

  Node $MachineName
  {
    #Install the IIS Role
    WindowsFeature IIS
    {
      Ensure = "Present"
      Name = "Web-Server"
    }

    #Install ASP.NET 4.5
    WindowsFeature ASP
    {
      Ensure = "Present"
      Name = "Web-Asp-Net45"
    }

     WindowsFeature WebServerManagementConsole
    {
        Name = "Web-Mgmt-Console"
        Ensure = "Present"
    }

    xWebsite DefaultWebsite
    {
        Ensure = "Present"
        Name = "Default Web Site"
        State = "Started"
        PhysicalPath = "C:\inetpub\wwwroot"
        BindingInfo = MSFT_xWebBindingInformation
        {
            Protocol = "HTTP"
            Port = 81
        }
        DependsOn = "[WindowsFeature]IIS"
    }

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


    xRemoteFile DownloadFile
    {
        DestinationPath = 'C:\inetpub\wwwroot\isstart.html'
        Uri             = $indexFileUrl
        MatchSource     = $false
    }
  }
} 