$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run elevated"
    read-host -Prompt "Press RETURN to exit"
    exit
}
Set-Location $PSScriptRoot
Add-Type -AssemblyName PresentationFramework

function SetIP(
    [int]$InterfaceIndex,
    [string]$IPAddress,
    [string]$SubnetMask
) {

    Write-Host "Attempting to configure network adapter '$InterfaceIndex'..."

    try {
        # Get the network adapter by its name
        $adapter = Get-NetAdapter -InterfaceIndex $InterfaceIndex -ErrorAction Stop

        Write-Host "Found adapter: $($adapter.Name) (Status: $($adapter.Status))"

        # Convert subnet mask to PrefixLength for New-NetIPAddress cmdlet
        # This is a common way to calculate PrefixLength from SubnetMask
        function Convert-SubnetMaskToPrefixLength ($Mask) {
            $MaskBytes = $Mask.Split('.') | ForEach-Object { [System.Convert]::ToByte($_) }
            $BinaryString = ($MaskBytes | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') }) -join ''
            return ($BinaryString -replace '0', '').Length
        }

        $PrefixLength = Convert-SubnetMaskToPrefixLength $SubnetMask

        Write-Host "Calculated PrefixLength: $PrefixLength"

        # Disable DHCP for the specified interface
        Write-Host "Disabling DHCP for adapter '$InterfaceIndex'..."
        Set-NetIPInterface -InterfaceIndex $InterfaceIndex -Dhcp Disabled -PolicyStore ActiveStore -ErrorAction Stop

        # Robustly remove any existing IPv4 addresses on the adapter to ensure a clean slate
        Write-Host "Attempting to remove existing IPv4 addresses from $($adapter.Name)..."
        $existingIPs = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingIPs) {
            foreach ($ip in $existingIPs) {
                Write-Host "Removing IP address: $($ip.IPAddress) (Type: $($ip.AddressFamily))"
                Remove-NetIPAddress -InputObject $ip -Confirm:$false -ErrorAction SilentlyContinue
            }
            # Give a small delay to allow the system to process the removal
            Start-Sleep -Seconds 1
            $remainingIPs = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($remainingIPs) {
                Write-Warning "Failed to remove all existing IPv4 addresses. Remaining: $($remainingIPs.IPAddress -join ', ')"
                throw "Failed to clear existing IP addresses. Cannot proceed with setting new IP."
            }
            else {
                Write-Host "Successfully removed all existing IPv4 addresses."
            }
        }
        else {
            Write-Host "No existing IPv4 addresses found to remove."
        }

        # Add the new static IP address and subnet mask
        Write-Host "Adding new IP address '$IPAddress' with PrefixLength '$PrefixLength' to $($adapter.Name)..."
        New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -PolicyStore ActiveStore -ErrorAction Stop

        Write-Host "Successfully set IP address '$IPAddress' and Subnet Mask '$SubnetMask' on adapter '$InterfaceIndex'."

    }
    catch {
        Write-Error "An error occurred: $_"
        Write-Error "Please ensure you are running PowerShell as an Administrator and the interface name is correct."
        Write-Error "You can list available network adapters with 'Get-NetAdapter'."
    }
}

Write-Host "Copying files" -Fore Green
Copy-Item $PSScriptRoot\*.* $ENV:USERPROFILE\desktop -Exclude @("*.ps1", "*.bat", "*.md", "*.xml", "PanasonicDrivers","PanDriversOnly",".git")
mkdir $ENV:USERPROFILE\desktop\Tutorials -Force
Copy-Item Tutorials $ENV:USERPROFILE\Desktop\Tutorials

$ImagePath = "$ENV:USERPROFILE\desktop\has.png"

# Set wallpaper style to Center
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "0"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $ImagePath

# Apply the wallpaper
Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

[Wallpaper]::SystemParametersInfo(20, 0, $ImagePath, 3)

Write-Host "Installing dependencies" -Fore Green

install-packageprovider nuget -force
Install-Module -Name PowerShellGet -Force -AllowClobber

Add-AppxPackage -Path https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx

if (-Not (get-appxpackage | where { $_.name -match 'UI.Xaml.2.8' })) {
    Add-AppxPackage .\microsoft.ui.xaml.2.8.6\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx
}
# Invoke-WebRequest -Uri https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6 -OutFile .\microsoft.ui.xaml.2.8.6.zip
# Expand-Archive .\microsoft.ui.xaml.2.8.6.zip

Write-Host "Downloading winget" -Fore Green
$nc = New-Object System.Net.WebClient

$nc.DownloadFile("https://aka.ms/getwingetpreview", "C:\windows\temp\winget.msixbundle")
Add-AppxPackage -Path "c:\windows\temp\winget.msixbundle"

Write-Host "Installing VLC and vscode" -Fore Green
winget install videolan.vlc --silent --accept-source-agreements
winget install anydesk.anydesk --silent --accept-source-agreements
winget install winaero.tweaker --silent --accept-source-agreements
winget install Microsoft.VCRedist.2005.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2005.x86 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2008.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2008.x86 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2010.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2010.x86 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2012.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2012.x86 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2013.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2013.x86 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2015+.x64 --silent --accept-source-agreements
winget install Microsoft.VCRedist.2015+.x86 --silent --accept-source-agreements
Add-MpPreference -ExclusionPath "C:\Program Files\Winaero Tweaker"
Add-MpPreference -ExclusionProcess "C:\Program Files\Winaero Tweaker\WinaeroTweaker.exe"
Copy-Item $PSScriptRoot\winarero.ini $ENV:USERPROFILE\desktop
winget install Python.Python.3.13 --silent --accept-source-agreements

cmd /c assoc .mp4=VLC.mp4.Document
cmd /c ftype VLC.mp4.Document="C:\Program Files\VideoLAN\VLC\vlc.exe" --started-from-file --no-playlist-enqueue "%1"
cmd /c assoc .mov=VLC.mov.Document
cmd /c ftype VLC.mov.Document="C:\Program Files\VideoLAN\VLC\vlc.exe" --started-from-file --no-playlist-enqueue "%1"

Write-Host "Installing AOG" -Fore Green

mkdir "C:\AgOpenGPS" -errorAction SilentlyContinue | Out-Null
cacls c:\AgOpenGPS /t /e /g everyone:f
Write-Host "Downloading AOG" -Fore Green

$assets = irm https://api.github.com/repos/AgOpenGPS-Official/AgOpenGPS/releases/latest | select -exp assets
$nc.DownloadFile($assets.browser_download_url, "C:\windows\temp\agopengps.zip")
Expand-Archive -Path "C:\windows\temp\AgOpenGPS.zip" -DestinationPath "C:\AgOpenGPS"
$dirs = Dir c:\agopengps -Directory
ForEach ($dir in $dirs) {
    move "c:\agopengps\$($dir.name)\*" "c:\agopengps" -Force
    Remove-Item "c:\agopengps\$($dir.name)" -Recurse
}

Write-Host "Downloading AOG" -Fore Green

$assets = irm https://api.github.com/repos/lansalot/AOGConfigOMatic/releases/latest | select -exp assets
$exeurl = $assets.browser_download_url | where {$_ -match '.exe'}
$nc.DownloadFile($exeurl, "C:\windows\temp\aogc.exe")
Unblock-File "C:\windows\temp\aogc.exe"
Start-Process "C:\windows\temp\aogc.exe" -ArgumentList "/SILENT", "/NOCANCEL", "/SUPPRESSMSGBOXES" -Wait

# Move stuff about just in case zip files folders etc

$TargetFile = "C:\AgOpenGPS\AgOpenGPS.exe"
$ShortcutFile = "$ENV:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\AgOpenGPS.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$ShortCut.WorkingDirectory = "c:\agopengps"
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()

$TargetFile = "C:\AgOpenGPS\AgOpenGPS.exe"
$ShortcutFile = "$ENV:USERPROFILE\desktop\AgOpenGPS.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$ShortCut.WorkingDirectory = "c:\agopengps"
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()


$ToRemove = @"
Clipchamp.Clipchamp
Microsoft.BingNews
Microsoft.BingWeather
Microsoft.GetHelp
Microsoft.MicrosoftOfficeHub
Microsoft.MicrosoftSolitaireCollection
Microsoft.PowerAutomateDesktop
Microsoft.WindowsFeedbackHub
Microsoft.WindowsTerminal
Microsoft.Xbox.TCUI
Microsoft.XboxGameOverlay
Microsoft.XboxGamingOverlay
Microsoft.XboxSpeechToTextOverlay
Microsoft.ZuneMusic
Microsoft.ZuneVideo
Microsoft.Getstarted
Microsoft.Windows.StartMenuExperienceHost
MSTeams
Microsoft.Paint
Microsoft.ScreenSketch
Microsoft.CoPilot
Microsoft.OneDriveSync
"@
$ProgressPreference = "SilentlyContinue"
ForEach ($Package in $ToRemove.Split("`n")) {
    Write-Output "Removing $Package"
    $pack = Get-AppxPackage -Name ($Package.Trim())
    if ($pack) {
        Remove-AppXPackage -Package $Pack.PackageFullName -ErrorAction SilentlyContinue
    }
}
$progressPreference = "Continue"
mkdir "$($ENV:USERPROFILE)\Documents\AgOpenGPS\AgIO" | Out-Null
Copy "$($PSScriptRoot)\agio\*.xml" "$($ENV:USERPROFILE)\Documents\AgOpenGPS\AgIO"

Write-Host "Setting WLAN config" -Fore Green
New-ItemProperty -Path HKLM:SOFTWARE\Policies\Microsoft\Windows\WcmSvc\Local -Name fMinimizeConnections -PropertyType DWORD -Value 0 | Out-Null

Write-Host "Enabling RDP" -Fore Green
# Enable Remote Desktop Protocol (RDP)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\LSA' -Name "LimitBlankPasswordUse" -Value 0 | Out-Null



Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
ipconfig | findstr /i ipv4

if ([System.Windows.MessageBox]::Show("Set up ethernet?", "Confirmation", "YesNo", "Question") -eq "Yes") {
    $eth = get-netadapter -physical | where { $_.MediaType -eq '802.3' }
    SetIP -InterfaceIndex $eth.InterfaceIndex -IPAddress "192.168.5.5" -SubnetMask "255.255.255.0"
}

if ([System.Windows.MessageBox]::Show("Do you want to restart ?", "Confirmation", "YesNo", "Question") -eq "Yes") {
    Restart-Computer -Force
}

Write-Output "Now, username shenanigans"
# Allow RDP through Windows Firewall (optional)

Rename-LocalUser -Name $ENV:USERNAME -NewName "aog"
$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
# Set-ItemProperty $RegistryPath 'AutoAdminLogon' -Value "1" -Type String | Out-Null
Remove-ItemProperty $RegistryPath 'DefaultUsername' -ErrorAction SilentlyContinue | Out-Null # -Value "owner" -type String  | Out-Null
Remove-ItemProperty $RegistryPath 'DefaultPassword' -ErrorAction SilentlyContinue | Out-Null # -Value "owner" -type String | Out-Null

Set-LocalUser -name "aog" -Password ([securestring]::new())
Set-LocalUser -name "aog" -AccountNeverExpires:$true

regedit -s anydesk.reg