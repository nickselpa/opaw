#Requires -Version 4
#Requires -RunAsAdministrator

# This is going to be a file that is copied to the target system that needs
# updates.  This is to work around the remote limitations leveraging WUA.
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa387288(v=vs.85).aspx
#
# Credit to sample script from MSDN providing the heavy lifting of
# orchestrating the WUA actions on the local system.
# (Converted from VB to PowerShell):
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa387102(v=vs.85).aspx



[CmdletBinding()]
param(
    [Parameter()]
    [switch]
    $ForceReboot
)

$wua_result_codes = [ordered]@{
    0 = 'NotStarted'
    1 = 'InProgress'
    2 = 'Succeeded'
    3 = 'SucceededWithErrors'
    4 = 'Failed'
    5 = 'Aborted' 
}


$lwu = new-object -ComObject "Microsoft.Update.Session"
$wusearcher = $lwu.CreateUpdateSearcher()
Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Searching Windows Updates with 'IsInstalled=0 and Type='Software' and IsHidden=0' ..."
$wusearchresult = $wusearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($wusearchresult.Updates.Count) Updates were found ..."
Start-Sleep -s 1
$wusearchresult.Updates | select title, cveids, description | Format-List

$wutodownload = New-Object -ComObject "Microsoft.Update.UpdateColl"

foreach ($update in $wusearchresult.Updates){
    if ($update.InstallationBehavior.CanRequestUserInput -ne $true) {
        if ($update.EulaAccepted -eq $false) {
            Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Auto-accepting EULA so patching may proceed ..."
            $update.AcceptEula() | Out-Null
        }
        $wutodownload.Add($update) | Out-Null

    } else {
        Write-Warning -Message "WARN [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] The update for KB ID(s): $($update.KBArticleIDs) has been skipped due to manual intervention being required ..."
    }
}

$wudownloader = $lwu.CreateUpdateDownloader()
$wudownloader.Updates = $wutodownload

if ($wudownloader.Updates.Count -gt 0) {
    Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Attempting to download updates ..."
    $wudownloader.Download() | Out-Null


    $wutoinstall = New-Object -ComObject "Microsoft.Update.UpdateColl"
    $wurebootreq = $false

    foreach ($update in $wusearchresult.Updates){
        if ($update.IsDownloaded -eq $true){
            $wutoinstall.Add($update) | Out-Null
        }
        if ($update.InstallationBehavior.RebootBehavior -gt 0) {
            $wurebootreq = $true
        }
    }

    if ($wutoinstall.Count -eq 0) {
        Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] No updates were downloaded for install ..."
    }

    if ($wurebootreq) {
        Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] The updates to be applied will require a reboot ..."
    }

    $wuinstaller = $lwu.CreateUpdateInstaller()
    $wuinstaller.Updates = $wutoinstall

    if ($wuinstaller.Updates.Count -gt 0) {
        Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Attempting to install updates ..."
        $wuinstallresult = $wuinstaller.Install()

        Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Installation result: $($wua_result_codes.($wuinstallresult.ResultCode))"
        Write-Output "INFO [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Reboot required: $wurebootreq"
        Write-Output "`nUpdates applied`n---------------"

        foreach ($update in $wutoinstall) {
            Write-Output $update.Title
        }

        #[10.21.20.102]: PS HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update>
        # May be able to check this for the need for pending restarts

        #if ($ForceReboot -or $wurebootreq) {
        #    Restart-Computer -Force -Confirm:$false
        #}
    }
# Position <Reboot [bool]>,<ResultCode [int32]>,<QtyUpdates [int32]>
Write-Output "$wurebootreq,$($wuinstallresult.ResultCode),$($wuinstaller.Updates.Count)"
} else {
    Write-Output "False,2,0"
}
