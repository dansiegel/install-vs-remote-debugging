<# 
.SYNOPSIS 
    Install IIS Server with Web Deploy
.DESCRIPTION 
    This will install the Web Server Role including all WebServer, Health, Performance, Security, and Application features. WCF Features
    will also be installed for the .NET 4.5 Framework. Web Platform Installer and Web Deploy for Hosting Servers are also installed. 
    After running this script your server will be ready for hosting most modern ASP.NET applications deployed directly from Visual Studio.
.NOTES 
    Author     : Dan Siegel - me@dansiegel.net
.LINK 
    https://dansiegel.github.io/
.ROLE
    Administrator
#> 

function IsAdministrator
{
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}


function IsUacEnabled
{
    (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).EnableLua -ne 0
}

if (!(IsAdministrator))
{
    if (IsUacEnabled)
    {
        [string[]]$argList = @('-NoProfile', '-NoExit', '-File', $MyInvocation.MyCommand.Path)
        $argList += $MyInvocation.BoundParameters.GetEnumerator() | Foreach {"-$($_.Key)", "$($_.Value)"}
        $argList += $MyInvocation.UnboundArguments
        Start-Process PowerShell.exe -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList 
        return
    }
    else
    {
        throw "You must be administrator to run this script"
    }
}

$null = Start-Job -Name AddWebServer -ScriptBlock { 
Add-WindowsFeature -Name "Web-Server" -IncludeManagementTools
#Web Server
Add-WindowsFeature -Name "Web-WebServer" -IncludeAllSubFeature -IncludeManagementTools  
#Health
Add-WindowsFeature -Name "Web-Health" -IncludeAllSubFeature -IncludeManagementTools 
#Performance
Add-WindowsFeature -Name "Web-Performance" -IncludeAllSubFeature -IncludeManagementTools 
#Security
Add-WindowsFeature -Name "Web-Security" -IncludeAllSubFeature -IncludeManagementTools 
#Application Development
Add-WindowsFeature -Name "Web-App-Dev" -IncludeAllSubFeature -IncludeManagementTools
#Management Tools
Add-WindowsFeature -Name "Web-Mgmt-Tools"
Add-WindowsFeature -Name "Web-Mgmt-Console" 
Add-WindowsFeature -Name "Web-Scripting-Tools"
Add-WindowsFeature -Name "Web-Mgmt-Service"
#WCF Features
Add-WindowsFeature -Name "NET-WCF-Services45" -IncludeAllSubFeature -IncludeManagementTools 
} 
Write-Host "Installing the Web Server Role"
$null = Wait-Job -Name AddWebServer

$WPIDirectory = "$env:ProgramFiles\Microsoft\Web Platform Installer"

$null = Start-Job -Name WebPlatformInstaller -ScriptBlock {
    $source = "http://go.microsoft.com/fwlink/?LinkId=255386"
    $destination = "$env:USERPROFILE\Downloads\wpilauncher.exe"
 
    Invoke-WebRequest $source -OutFile $destination
    Invoke-Item -Path $destination
    # We just want to wait a few seconds to ensure that WPI is installed before continuing.
    Start-Sleep -Seconds 10
}
Write-Host "Installing the Web Platform Installer"
$null = Wait-Job -Name WebPlatformInstaller

$null = Start-Job -Name WebDeploy -ScriptBlock {
    cd $WPIDirectory
    .\WebpiCmd-x64.exe /Install /Products:WDeployPS /AcceptEula
}
Write-Host "Installing Web Deploy for Hosting Servers"
$null = Wait-Job -Name WebDeploy

Write-Host "The Web Server Role, and Web Deploy have been installed."