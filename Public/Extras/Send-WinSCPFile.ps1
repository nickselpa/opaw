#Requires -Version 5
#Requires -RunAsAdministrator

## TODO: WinSCP for file transfers to a remote host
## Credit to sample script at:
## https://winscp.net/eng/docs/script_local_move_after_successful_upload

## TODO: Comment based help
Function Send-WinSCPFile
{
    [Cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ComputerName,
        [Parameter()]
        [Int32]
        $TCPPort = 22,
        [Parameter(Mandatory=$true)]
        [String]
        $Username,
        [Parameter()]
        [System.Security.SecureString]
        $Password,
        [Parameter()]
        [ValidateScript({Test-Path -Path $_ -PathType leaf -IsValid -Verbose})]
        [String]
        $SSHPrivateKeyPath,
        [Parameter()]
        [String]
        $SSHHostFingerprint,
        [Parameter(Mandatory=$true)]
        [ValidateScript({(Test-Path -Path $_ -PathType 'leaf' -IsValid) -or 
                         (Test-Path -Path $_ -PathType 'container' -IsValid)})]
        [String]
        $LocalPath,
        [Parameter(Mandatory=$true)]
        [String]
        $RemotePath,
        [Parameter()]
        [String]
        $WinSCPPath
    )
    
    try
    {
        # Load WinSCP .NET assembly
        Write-Verbose "Attempting to load WinSCP assemblies for transfer ..."
        if ($PSBoundParameters.ContainsKey('winscpPath')) {
            Add-Type -Path $winscpPath -ErrorAction 'Stop'
        } else {
            Write-Verbose 'No path explicitly specified.  Looking for assembly in default install location for WinSCP'
            $winscpLib = Get-ChildItem -Path 'C:\Program Files (x86)\WinSCP' -Filter 'winscpnet.dll' -File -Recurse
            if ($winscpLib.Count -eq 1) {
                Add-Type -Path $winscpLib.FullName -ErrorAction 'Stop'
            } elseif ($winscpLib.Count -gt 1) {
                Write-Error 'More than one WinSCP dll found.  Please provide an absolute path to the library you wish to use.'
            } else {
                Write-Error 'No WinSCP dll found.  Please provide an absolute path to the library you wish to use.'
            }
        }
        
    
        # Setup session options (common regardless of credential type)

        # a SSH private key will supersede a password credential if both happen
        # to be specified 
        if ($PSBoundParameters.ContainsKey('SSHPrivateKeyPath')) {
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Scp
                HostName = $ComputerName
                UserName = $Username
                # Host fingerprint format is: 'ssh-rsa 2048 aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99'
                SshHostKeyFingerprint = $SSHHostFingerprint
                SshPrivateKeyPath = $SSHPrivateKeyPath
            }  
        } elseif ($PSBoundParameters.ContainsKey('SSHPrivateKeyPath')) {
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                    Protocol = [WinSCP.Protocol]::Scp
                    HostName = $ComputerName
                    UserName = $Username
                    # Host fingerprint format is: 'ssh-rsa 2048 aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99'
                    SshHostKeyFingerprint = $SSHHostFingerprint
                    Password = $Password
            }  
        } else { Write-Error 'No SSH private key (.ppk) or password was provided to complete the credential.  Exiting ...'; return 2 }

    
        Write-Verbose 'Instantiating new WinSCP object'
        $session = New-Object WinSCP.Session
    
        try
        {
            # Connect
            Write-Verbose "Connecting to ${ComputerName}:${TCPPort} ..."
            $session.Open($sessionOptions)
    
            # Upload files, collect results
            Write-Verbose "Uploading file $localPath to ${ComputerName}:${TCPPort} ..."
            $transferResult = $session.PutFiles($localPath, $remotePath)
    
            # Iterate over every transfer
            Write-Verbose "Transfer results from $localPath to ${ComputerName}:${TCPPort} ..."
            foreach ($transfer in $transferResult.Transfers)
            {
                # Success or error?
                if ($transfer.Error -eq $Null)
                {
                    Write-Verbose ("Upload of {0} succeeded" -f $transfer.FileName)
                }
                else
                {
                    Write-Verbose ("Upload of {0} failed: {1}" -f
                        $transfer.FileName, $transfer.Error.Message)
                }
            }
        }
        finally
        {
            # Disconnect, clean up
            $session.Dispose()
        }
    
        return 0
    }
    catch [Exception]
    {
        Write-Host ("Error: {0}" -f $_.Exception.Message)
        return 1
    }
}