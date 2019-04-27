Function Get-VMDiskConfiguration {
    <#
    .SYNOPSIS
    Capture a snapshot of a Hyper-V virtual machine's disk configuration.

    .DESCRIPTION
    This function will either return all disks for a VM and return all objects
    associated with the VM.  Additionally, if you're interested in a specific
    disk's configuration on a VM, it may be pared down to just the single VHD
    absolute path.

    Author's note: This was created to circumvent a behavior where future uses
    of a variable that contained what were to expected to be static captures of
    a VM's configuration we being dynamically updated on future executions.
    The described behavior was undesirable.

    .PARAMETER VMName
    Name of the Hyper-V virtual machine to collect disk information from.

    .PARAMETER VHDPath
    Absolute path to VHD or VHDX that accompanies the VM specified in VMName. 

    .EXAMPLE

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $VMName,
        [Parameter()]
        [String]
        $VHDPath
    )

    $_disks = @()

    if ($PSBoundParameters.ContainsKey('VHDPath')) {
        return $(Get-VM $VMName | 
                 Get-VMHardDiskDrive | 
                 Where-Object -Property Path -eq $VHDPath)
    } else {
        foreach ($vmdisk in $(Get-VM $VMName | Get-VMHardDiskDrive)) {
        $_disks += $vmdisk
        }
    }
    
    return $_disks

}