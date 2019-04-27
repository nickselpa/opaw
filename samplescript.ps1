#Requires -Version 5
#Requires -RunAsAdministrator

#$opaw_location = 'C:\gitrepos\opaw'

# This is until I make the proper opaw module
#if (Test-Path -LiteralPath $opaw_location -PathType 'Container' -IsValid) {
#    . C:\gitrepos\opaw\opaw-initialize.ps1
#    . C:\gitrepos\opaw\opaw-functions.ps1
#    . C:\gitrepos\opaw\opaw-extras.ps1
#}
Import-Module -Name 'OPAW' -Verbose

$username = 'Administrator'
$password = ConvertTo-SecureString "Password!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

$TargetVM = [ordered]@{
    'ComputerName' = '192.168.1.10'
        'Username' = 'Administrator'
        'Password' = 'Password!'
      'HelperFile' = "C:\gitrepos\opaw\opaw-wuapayload.ps1"
      'RemotePath' = 'C:\'
       'LogFolder' = 'C:\opawlogs\updates'
       'PSSession' = ''
  'RebootIfNeeded' = $true
}

$TargetVMSysprep = [ordered]@{
          'VMName' = '2008R2Capture'
          'OSType' = '2008R2'
    'ComputerName' = '192.168.1.10'
            'Name' = 'Windows Server 2008 R2 SERVERENTERPRISE'
     'Description' = 'Windows Server 2008 R2 SERVERENTERPRISE'
      'Credential' = $credential
}

$scp_target = @{
         'ComputerName' = 'scp.remoteserver.doesntexist'
             'Username' = 'remoteuser'
            'LocalPath' = ''
           'RemotePath' = '/home/remoteuser/'
    'SSHPrivateKeyPath' = 'C:\OPAW\Keys\scp.remoteserver.doesntexist-privkey.ppk'
   'SSHHostFingerprint' = 'ssh-rsa 2048 aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99'
              'Verbose' = $true
}

# This function is quick and dirty and long overdue
Function Patch-Capture-And-Send {
    [CmdletBinding()]
    param(
        $TargetOS,
        $TargetOSSysprep,
        $SCPDestination
    )
    do {
        # Check if WSMan remote port is shown as listening
        if (Test-TCPServiceConnectivity -ComputerName $($TargetOS.ComputerName) -TCPPort 5985 -Retries 100 -Verbose) {
            $TargetOS.PSSession = New-PSSession -ComputerName $($TargetOS.ComputerName) -Credential $credential
            $_updateattempt = Invoke-RemoteWindowsUpdate @TargetOS -Verbose -ErrorAction 'Stop'
            Start-Sleep -s 60
        }
        $_updateloops += 1
        Remove-PSSession -Session $($TargetOS.PSSession)
        if ($_updateloops -gt 20) {break}
        # Exit codes:
        # 0: success; reboot required
        # 1: success; no reboot required
        # 2: failed (not implemented)
    } while ($_updateattempt -eq 0)

    if ($_updateattempt -eq 1) {
        $wimpath = Invoke-RemoteSysprepCapture @TargetOSSysprep -Verbose
    }

    if (Test-Path -LiteralPath $wimpath -PathType 'Leaf' -IsValid){
        $SCPDestination.LocalPath = $wimpath.ImagePath
        Send-WinSCPFile @SCPDestination
    }
}

Patch-Capture-And-Send -TargetOS $TargetVM -TargetOSSysprep $TargetVMSysprep -SCPDestination $scp_target -Verbose

