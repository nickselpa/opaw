Function Invoke-PSExecSession {
    <#
    .SYNOPSIS
    A PowerShell wrapper for invoking PsExec64.exe.

    .DESCRIPTION
    This allows for a PowerShell-styled use of PsExec64.  This function also
    has built-in logging of stdout and stderr from the external execution.

    The reason for using this cmdlet versus using native Powershell remoting
    is if there is something on the remote system that requires a local
    session to execute.  PsExec provides a way to start a session and have
    it look like a local execution.

    The function returns a value only when the LogFolder parameter is used.
    What is returned is a string representation of the time in ticks when
    the job task was started.

    Please see the documentation for PsExec64 for a better context of the
    command to parameter mappings if you're unfamiliar with PsExec64.

    .PARAMETER ComputerName
    FQDN or IP address of remote system to execute commands against.

    .PARAMETER Username
    Username to use for remote commands.  Please ensure the user account used
    has the appropriate permissions on the remote system.

    .PARAMETER Password
    Credential used that compliments the Username parameter.

    .PARAMETER CommandPath
    Absolute path of the program you wish to execute on the remote computer.

    .PARAMETER CommandArgs
    The arguments needed to be passed to the program to be executed on the
    remote computer.

    .PARAMETER PSExecPath
    The absolute path to the version of PSExec you want to use.  If no location
    is specified, the cmdlet will try and discover an available PsExec64.exe
    that is in the environment PATH.

    .PARAMETER LogFolder
    Enables logging and specifies the logging location for the remote command
    execution.  The folder will contain two files: One named PSExecStdOut for
    the standard output and PSExecStdErr for the standard error outputs
    respectively.  They will also have a filename suffix, represented in ticks,
    to prevent logs being overwritten between executions.

    Using this parameter will return a timestamp in ticks when the job was
    started.

    .PARAMETER ElevateUAC
    Elevates the remote session to the required UAC level for execution if it
    is required for successful execution.

    .PARAMETER AcceptPSExecEULA
    Accepts the EULA for using PSExec.  This switch parameter is mandatory.

    .PARAMETER Noninteractive
    This switch will allow for an asynchronous execution of a remote command
    if there is no requirement to wait for the process to complete in its
    usage.

    .EXAMPLE
        $_psexecparams = [ordered]@{
            'ComputerName' = 'target01.contoso.com'
                'Username' = 'Administrator'
                'Password' = 'SamplePassword!'
        'AcceptPSExecEULA' = $true
              'ElevateUAC' = $true
             'CommandPath' = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
             'CommandArgs' = "-ExecutionPolicy Bypass -Noninteractive -File C:\scripts\script-to-run.ps1"
        }

        Invoke-PSExecSession @_psexecparams

    The example pre-defines all of the mandatory parameters in addition to
    parameters needed to run a remote PowerShell session.  That dictionary
    is then splatted into Invoke-PSExecSession.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String[]]
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
        [String]
        $CommandPath,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $CommandArgs,
        [Parameter()]
        [ValidateScript({(Test-Path -LiteralPath $_ -PathType leaf -IsValid -Verbose) -and ($_ -imatch "^\S+psexec6?4?\.exe$")})]
        [ValidateNotNullOrEmpty()]
        [String]
        $PSExecPath,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $LogFolder,
        [Parameter()]
        [Switch]
        $ElevateUAC,
        [Parameter(Mandatory=$true)]
        [Switch]
        $AcceptPSExecEULA,
        [Parameter()]
        [Switch]
        $Noninteractive
    )

    # PSExec will always be an interactive execution. Start-Process will
    # determine the non-interactive behavior when called.

    # There's probably a better way to sanitize this, but, I wanted to ensure this was
    # implemented and working in a more secure fashion.
    
    $_arguments = '-nobanner'
    $_arguments_verbose = $_arguments

    switch ($PSBoundParameters.Keys){
              'ElevateUAC' { $_arguments += ' -h' ; $_arguments_verbose += ' -h' }
        'AcceptPSExecEULA' { $_arguments += ' -accepteula' ; $_arguments_verbose += ' -accepteula' }
                'Username' { $_arguments += " -u $Username" ; $_arguments_verbose += " -u $Username" }
                'Password' { $_arguments += " -p $Password" ; $_arguments_verbose += " -p ##REDACTED##" }
             'CommandPath' { $_arguments += " $CommandPath" ; $_arguments_verbose += " $CommandPath" }
             'CommandArgs' { $_arguments += " $CommandArgs" ; $_arguments_verbose += " $CommandArgs" }
    }

    if (-not $PSBoundParameters.ContainsKey('PSExecPath')){
        $PSExecPath = (Get-Command PsExec64.exe -ErrorAction Stop).Source
    }

    foreach ($c in $ComputerName){
        try {
            if ($PSBoundParameters.ContainsKey('LogFolder')){
                $_logfilesuffix = [string]$(Get-Date).Ticks
                if (-not $(Test-Path -LiteralPath $LogFolder -PathType 'Container')){
                    New-Item -ItemType 'Directory' -Path $LogFolder -Force
                }
                $_logfilestd = "$LogFolder\PSExecStdOut-$_logfilesuffix.txt"
                $_logfileerr = "$LogFolder\PSExecStdErr-$_logfilesuffix.txt"

                Write-Debug "`$c = $c"
                Write-Debug "`$_arguments = $_arguments"
                Write-Debug "`$PSExecPath = $PSExecPath"
                Write-Debug "`$_logfilestd = $_logfilestd"
                Write-Debug "`$_logfileerr = $_logfileerr"

                Write-Verbose "PSExec64 Log found at $_logfileerr ..."
                Write-Verbose "Script Stdout Log found at $_logfilestd ..."
                Write-Verbose "Executing PSExec64 with arguments $_arguments_verbose to remote computer $c ..."

                if ($PSBoundParameters.ContainsKey('Noninteractive')){
                    Start-Process -FilePath $PSExecPath -ArgumentList "\\$c $_arguments" -RedirectStandardError $_logfileerr -RedirectStandardOutput $_logfilestd -NoNewWindow
                } else {
                    Start-Process -FilePath $PSExecPath -ArgumentList "\\$c $_arguments" -RedirectStandardError $_logfileerr -RedirectStandardOutput $_logfilestd -NoNewWindow -Wait
                }

                return $_logfilesuffix
            } else {
                Write-Verbose "`$c = $c"
                Write-Verbose "`$_arguments = $_arguments"
                Write-Verbose "`$PSExecPath = $PSExecPath"

                Write-Verbose "Executing PSExec64 with arguments $_arguments to remote computer $c ..."
                
                if ($PSBoundParameters.ContainsKey('Noninteractive')){
                    Start-Process -FilePath $PSExecPath -ArgumentList "\\$c $_arguments" -NoNewWindow
                } else {
                    Start-Process -FilePath $PSExecPath -ArgumentList "\\$c $_arguments" -NoNewWindow -Wait
                }
            }
        } catch {
            Write-Error -Message $Error[0].Exception -ErrorAction 'Stop'
        }
    }
}
