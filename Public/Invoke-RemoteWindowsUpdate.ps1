Function Invoke-RemoteWindowsUpdate {
    <#
    .SYNOPSIS
    Invokes a remote run of Windows Update using a helper file staged on the
    target system.

    .DESCRIPTION
    Using PsExec, specifically the Invoke-PSExecSession function, a helper
    file is staged on the remote system to invoke Windows Updates and make the
    remote execution look like it was invoked locally.

    This is required due to a documented limitation of the Windows Update Agent
    masking certain methods as being unavailable.  See 
    https://msdn.microsoft.com/en-us/library/windows/desktop/aa387288(v=vs.85).aspx
    for more information.

    .PARAMETER ComputerName
    FQDN or IP address of remote system to execute commands against.

    .PARAMETER Username
    Username to use for remote commands.  Please ensure the user account used
    has the appropriate permissions on the remote system.

    .PARAMETER Password
    Credential used that compliments the Username parameter.

    .PARAMETER HelperFile
    Windows Update helper file to stage on remote system.

    .PARAMETER RemotePath
    Absolute path to save helper file on the remote system.

    .PARAMETER LogFolder
    Enables logging and specifies the logging location for the remote command
    execution.  The folder will contain two files: One named PSExecStdOut for
    the standard output and PSExecStdErr for the standard error outputs
    respectively.  They will also have a filename suffix, represented in ticks,
    to prevent logs being overwritten between executions.

    .PARAMETER PSSession
    The PSSession object for the remote system.

    .PARAMETER RebootIfNeeded
    This switch will attempt a graceful reboot of the remote system if a
    restart is pending post-updates.  This is dependent on the LogFolder
    parameter being used to trigger the update.

    .EXAMPLE
    $example_session = New-PSSession -ComputerName 'example01.contoso.com' -Credential (Get-Credential)

    $function_params = [ordered]@{
        'ComputerName' = 'example01.contoso.com'
        'Username' = 'Administrator'
        'Password' = 'SamplePassword!'
        'UpdatesFile' = 'C:\HelperFiles\wua-helper.ps1'
        'RemotePath' = 'C:\RemoteHelper'
        'LogFolder' = 'C:\RemoteWindowsUpdates\Logs\'
        'PSSession' = $example_session
    }

    Start-RemoteWindowsUpdate @function_params

    Creates a new PSSession, defines all the parameters to pass into the
    function and then splats the dictionary function_params into
    Start-RemoteWindowsUpdate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 2 -Quiet})]
        [String]
        $ComputerName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Username,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Password,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_ -PathType leaf -IsValid -Verbose})]
        [String]
        $HelperFile,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $RemotePath,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $LogFolder,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_.State -eq 'Opened'})]
        [System.Management.Automation.Runspaces.PSSession]
        $PSSession,
        [Parameter()]
        [Switch]
        $RebootIfNeeded
    )

    try {
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 50 -Message "Attempting to copy $HelperFile using remote session $($PSSession.Name) to $RemotePath on remote file system" -ErrorAction 'SilentlyContinue' 
        Copy-Item -Path $HelperFile -Destination $RemotePath -ToSession $PSSession -Force -ErrorAction 'Stop'
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 51 -Message "Remote file copy of $HelperFile over remote session $($PSSession.Name) was successful." -ErrorAction 'SilentlyContinue'
        $_localfile = Get-ChildItem -Path $HelperFile | Select-Object -ExpandProperty 'Name'
        
        if ($RemotePath -match "[\\/]{1}$") {
            $RemotePath = $RemotePath -replace '/','\'
            $_remotefile = "${RemotePath}${_localfile}"
        } else {
            $_remotefile = "${RemotePath}\${_localfile}"
        }

        Write-Verbose "`$_remotefile = $_remotefile"

        # This has to be ordered to ensure the params are splatted into
        # Invoke-PSExecSession in the correct order/orientation
        $_psexecparams = [ordered]@{
                'ComputerName' = $ComputerName
                    'Username' = $Username
                    'Password' = $Password
            'AcceptPSExecEULA' = $true
                  'ElevateUAC' = $true
                 'CommandPath' = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
                 'CommandArgs' = "-ExecutionPolicy Bypass -Noninteractive -File $_remotefile"
        }

        if ($PSBoundParameters.ContainsKey('LogFolder')) {
            $_psexecparams.Add('LogFolder',$LogFolder)
        }

        Write-Debug ($_psexecparams | Out-String)

        $_remoteresult = Invoke-PSExecSession @_psexecparams
        Invoke-Command -Session $PSSession -ScriptBlock {Remove-Item -Path $using:_remotefile -Force}

        if ($RebootIfNeeded) {
            if ($PSBoundParameters.ContainsKey('LogFolder')) {
                # A better way to accomplish this is to read the remote registry but
                # I want v1 out the door and will add this as an issue into Gitlab
                
                # Comma-separated; The values are consumed as a string
                # Position <Reboot [bool]>,<ResultCode [int32]>,<QtyUpdates [int32]> 
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 52 -Message "Checking to see if reboot is required for the remote session $($PSSession.Name)" -ErrorAction 'SilentlyContinue'
                $_updatestatus = (Get-Content -Path "$LogFolder\PSExecStdOut-$_remoteresult.txt" -Tail 1).Split(',')
                if ($_updatestatus[0] -eq 'true' -and $_updatestatus[1] -eq '2') {
                    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 53 -Message "Reboot required for remote session.  Rebooting system." -ErrorAction 'SilentlyContinue'
                    Invoke-Command -Session $PSSession -ScriptBlock {Restart-Computer}
                    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 54 -Message "Reboot sent; $($_updatestatus[2]) update(s) were installed; Removing PSSession $($PSSession.ID) ..." -ErrorAction 'SilentlyContinue'
                    Write-Verbose "Reboot sent; $($_updatestatus[2]) update(s) were installed; Removing PSSession $($PSSession.ID) ..."
                    Remove-PSSession -Session $PSSession
                    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 0 -Message "Start-RemoteWindowsUpdate completed with reboot sent to $ComputerName" -ErrorAction 'SilentlyContinue'
                    return 0
                } elseif ($_updatestatus[0] -eq 'false' -and $_updatestatus[1] -eq '2') {
                    Write-Verbose "No reboot required.  $($_updatestatus[2]) update(s) were installed."
                    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 1 -Message "Start-RemoteWindowsUpdate completed with no reboot sent to $ComputerName" -ErrorAction 'SilentlyContinue'
                    return 1
                } else {
                    # A return code of 2 indicates failure.
                    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Warning' -EventId 2 -Message "The remote action on $ComputerName succeeded but the exit code was undetermined." -ErrorAction 'SilentlyContinue'
                    return 2
                }
                
            } else {
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Warning' -EventId 99 -Message "Start-RemoteWindowsUpdate failed with:`n`n$($Error[0] | Out-String)" -ErrorAction 'SilentlyContinue'
                Write-Warning -Message 'Reboot check specified with no logs.  Will not attempt reboot.'
            }
        }
    } catch {
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Error' -EventId 99 -Message "Start-RemoteWindowsUpdate failed with:`n`n$($Error[0] | Out-String)" -ErrorAction 'SilentlyContinue'
        Write-Error -Message $Error[0].Exception -ErrorAction 'Stop'
    }
    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 0 -Message "Start-RemoteWindowsUpdate to $ComputerName completed successfully ..." -ErrorAction 'SilentlyContinue'
}
