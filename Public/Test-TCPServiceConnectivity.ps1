Function Test-TCPServiceConnectivity {
    <#
    .SYNOPSIS
    Checks to see if a TCP service is available within a set number of retries.

    .DESCRIPTION
    Test-Connection has a Count feature that allows for multiple ICMP requests
    be sent.  Test-NetConnection, however, only checks to see if ICMP and the
    remote port are available for one pass.  This allows a user to wait for a 
    remote service to become available.  If the service does not become
    available after the retry threshold is exceeded, the function returns
    $false.

    .PARAMETER ComputerName
    FQDN or IP address of remote system.

    .PARAMETER TCPPort
    Remote TCP port to check service connectivity against.

    .PARAMETER Retries
    Number of attempts to take before failing the check.
    The default value is 10.

    .PARAMETER ShouldFail
    A switch that allows for the behavior to be flipped (a service going down
    would return $true instead of $false).

    This parameter can be used to wait for a service to stop before proceeding.

    .EXAMPLE
    Test-TCPServiceConnectivity -ComputerName 192.168.100.1 -TCPPort 80 -Retries 100

    Waiting for a web server to become available after 100 tries.
    #>
    # built-in Test-NetConnection does not have built-in retry functionality 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ComputerName,
        [Parameter(Mandatory=$true)]
        [Int32]
        $TCPPort,
        [Parameter()]
        [Int32]
        $Retries = 10,
        [Parameter()]
        [Switch]
        $ShouldFail
    )

    $_attempts = 0
    
    # The boolean will read inverted because of the do/while conditional
    if ($PSBoundParameters.ContainsKey('ShouldFail')){
        $_tcp_succeed = $true
    } else {
        $_tcp_succeed = $false
    }

    do {    
        $_is_alive = Test-NetConnection -ComputerName $ComputerName -Port $TCPPort
        $_attempts += 1
    } while ($_is_alive.TcpTestSucceeded -eq $_tcp_succeed -and $_attempts -lt $Retries)

    if ($_attempts -ge $Retries) {
        Write-Verbose "The remote computer at ${ComputerName}:${TCPPort} never reached the desired state ..."
        return $false
    }

    return $true

}