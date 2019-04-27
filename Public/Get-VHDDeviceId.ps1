Function Get-VHDDeviceId {
    <#
    .SYNOPSIS
    Collects the OS Disk ID of a mounted VHD/VHDX.

    .DESCRIPTION
    This will use WMI to collect an object with all of the attributes of the
    disk that matches the path specified.

    This requires the ROOT\Virtualization\v2 namespace be present on the system
    to work as expected.

    .PARAMETER VHDPath
    The absolute path to the mounted VHD or VHDX file.

    .EXAMPLE
    $vm_disk_sysprep_path = 'C:\HardDisks\image-sysprepped.vhdx'
    $MountedVHD = Get-VHDDeviceId -VHDPath $vm_disk_sysprep_path
    $MountedDisk = Get-Disk | Where-Object -Property Path -eq $MountedVHD.pnpdevicepath

    Gets the device ID for the specified VHDX in $vm_disk_sysprep_path and then
    uses that information to ensure the disk selected in the operating system
    context is indeed the VHDX.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $VHDPath
    )

    $_mountedvhd = Get-CimInstance -Namespace 'root\virtualization\v2' -ClassName 'Msvm_MountedStorageImage' |
      Where-Object -Property 'Name' -eq $VHDPath
    return $_mountedvhd

}