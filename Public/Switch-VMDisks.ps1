Function Switch-VMDisks {
    <#
    .SYNOPSIS
    Switch the source disk with the specified destination disk for a Hyper-V
    virtual machine.

    .DESCRIPTION
    When a target disk to switch is defined, the controller number and device
    number of on the controller are captured.  Then, the new disk is added to
    the VM, the target disk removed from the VM, and the new disk moved into
    the ControllerNumber and ControllerLocation of the target disk.

    .PARAMETER VMName
    Name of the Hyper-V virtual machine.

    .PARAMETER SourceDiskPath
    The original VHD or VHDX disk absolute path that needs to be switched for
    the specified virtual machine.

    .PARAMETER DestinationDiskPath
    The VHD or VHDX disk absolute path of the disk you want to replace in
    SourceDiskPath.

    .EXAMPLE
    $vm_disks_to_switch = @{
        'VMName' = 'ContosoVM'
        'SourceDiskPath' = 'C:\Virtual Machines\Hard Disks\olddisk.vhdx'
        'DestinationDiskPath = 'C:\Virtual Machines\Hard Disks\newdisk.vhdx'
    }
    
    Switch-VMDisks @vm_disks_to_switch

    Created a dictionary of parameters to splat into Switch-VMDisks.
    #>
    # decided to make this function more generic than single purpose for
    # potential future reuse
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $VMName,
        [Parameter(Mandatory=$true)]
        $SourceDiskPath,
        [Parameter(Mandatory=$true)]
        $DestinationDiskPath
    )

    $_source_disk_present = $(Get-VM $VMName |
                              Get-VMHardDiskDrive | 
                              Select-Object -ExpandProperty Path) -contains $SourceDiskPath  

    if ($_source_disk_present) {
        # forcing a custom object through Select-Object to ensure the data is
        # static
        $_source_disk = Get-VM -VMName $VMName |
          Get-VMHardDiskDrive |
          Where-Object -Property Path -eq $SourceDiskPath |
          Select-Object -Property ControllerType,
                                  ControllerNumber,
                                  ControllerLocation,
                                  Path,
                                  VMName  
        
        # Add the destination disk
        Add-VMHardDiskDrive -VMName $VMName -Path $DestinationDiskPath

        $_destination_disk =  Get-VM -VMName $VMName |
          Get-VMHardDiskDrive


        Get-VM -VMName $VMName |
          Get-VMHardDiskDrive |
          Where-Object -Property Path -eq $_source_disk.Path |
          Remove-VMHardDiskDrive

        $_destination_disk |
          Set-VMHardDiskDrive -VMName $VMName -ToControllerNumber $_source_disk.ControllerNumber -ToControllerLocation $_source_disk.ControllerLocation 

    } else {
        Write-Error -Message "Source disk $SourceDiskPath is not configured for VM $VMName ..."
    }

}