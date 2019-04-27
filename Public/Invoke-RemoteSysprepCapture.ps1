Function Invoke-RemoteSysprepCapture {
    <#
    .SYNOPSIS
    Captures target remote Hyper-V virtual machine after performing a remote
    sysprep of the targeted system.  

    .DESCRIPTION
    The following occurs to the targeted Hyper-V VM:
        + The target VM is powered down
        + The target VM system disk is used as a source for a new differencing
          disk
        + Diff disk is configured as the new primary disk for VM
        + Target VM is powered on off of diff disk
        + Run a remote sysprep action against system
        + On power off, mount differencing disk to Hyper-V host
        + Find drive letter of mounted disk and capture install WIM from disk
        + Reconfigure target VM to use original disk
        + Confirm VM powers on and responds normally after failback
        + Deletes differencing disk after successful failback

    The function will return Microsoft.Dism.Commands.OfflineImageObject after a
    Windows Image is successfully created.

    .PARAMETER VMName
    The Hyper-V VM name to target for sysprep.

    .PARAMETER OSType
    The target guest OS type.  Must be 2008R2, 2012R2, 2012R2, or 2016R0
    TODO: Maybe put OS discovery into the function instead of asking for it.

    .PARAMETER ComputerName
    FQDN or IP Address of the VMName specified.

    .PARAMETER WinRMPort
    The TCP port to use for WinRM transport.  If no port is specified, the 
    default value is 5985.

    Alias is also TCPPort

    .PARAMETER Name
    The Name attribute to specify for the WIM image creation.

    Alias is also WIMIndexName

    .PARAMETER Description
    The Description attribute to specify for the WIM image creation.

    Alias is also WIMIndexDescription

    .PARAMETER ServiceRetries
    Number of times to retry if a remote service is listening.  The default
    value is 100. 

    .PARAMETER Credential
    A System.Management.Automation.PSCredential object that should contain
    a user account with administrative privileges for the target VM.

    .EXAMPLE
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $VMName,
        [Parameter(Mandatory=$true)]
        [ValidateSet('2008R2','2012R0','2012R2', '2016R0')]
        [String]
        $OSType,
        [Parameter(Mandatory=$true)]
        [String]
        $ComputerName,
        [Parameter()]
        [Alias("TCPPort")]
        [ValidateNotNullOrEmpty()]
        [Int32]
        $WinRMPort = 5985,
        [Parameter(Mandatory=$true)]
        [Alias("WIMIndexName")]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        [Parameter(Mandatory=$true)]
        [Alias("WIMIndexDescription")]
        [ValidateNotNullOrEmpty()]
        [String]
        $Description,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Int32]
        $ServiceRetries = 100,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    # This may no longer be needed; To be replaced by parameter
    # $VMNotes = Get-VMCaptureNotes -VMName $VMName

    # Used to ensure guest VM only has one disk attached
    $vmdisk = Get-VM -VMName $VMName | Get-VMHardDiskDrive

    Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 300 -Message "Checking virtual machine $VMName for one configured virtual disk." -ErrorAction 'SilentlyContinue'
    if ($vmdisk.Count -eq 1){
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 301 -Message "Virtual machine $VMName is configured with only virtual disk; Proceeding with virtual disk operations." -ErrorAction 'SilentlyContinue'
        Write-Verbose "VM to capture is configured with only one disk; Safe to proceed ..."

        # Gracefully power off VM to process
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 302 -Message "Stopping Virtual machine $VMName ..." -ErrorAction 'SilentlyContinue'
        Stop-VM -VMName $VMName -ErrorAction 'Stop' | Out-Null
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 303 -Message "Virtual machine $VMName successfully stopped." -ErrorAction 'SilentlyContinue'

        # Strings for Before and After VM Disks
        $vm_disk_original_path = Get-VM -VMName $VMName | 
                                 Get-VMHardDiskDrive | 
                                 Select-Object -ExpandProperty 'Path'
        $vm_disk_sysprep_path = "$(Split-Path -Path $vm_disk_original_path -Parent)\$OSType-ToSysprep.vhdx"

        try {
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 310 -Message "Creating differencing disk $vm_disk_sysprep_path from source disk $vm_disk_original_path ..." -ErrorAction 'SilentlyContinue'
            New-VHD -Differencing -ParentPath $vm_disk_original_path -Path $vm_disk_sysprep_path -ErrorAction Stop | Out-Null
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 311 -Message "Disk $vm_disk_sysprep_path successfully created." -ErrorAction 'SilentlyContinue'

            # May be able to clean this up
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 312 -Message "Configuring virtual machine $VMName with disk $vm_disk_sysprep_path" -ErrorAction 'SilentlyContinue'
            Switch-VMDisks -VMName $VMName -SourceDiskPath $vm_disk_original_path -DestinationDiskPath $vm_disk_sysprep_path | Out-Null
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 313 -Message "Virtual machine $VMName disk configuration successfully changed." -ErrorAction 'SilentlyContinue'

            if ($(Get-VM -VMName $VMName).State -eq 'Off') {
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 314 -Message "Attempting to start $VMName ..." -ErrorAction 'SilentlyContinue'
                Start-VM -VMName $VMName | Out-Null
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 315 -Message "Virtual machine $VMName successfully started." -ErrorAction 'SilentlyContinue'
            }

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 320 -Message "Waiting for ${ComputerName}:$WinRMPort to become available for WSMan/WinRM ..." -ErrorAction 'SilentlyContinue'
            Test-TCPServiceConnectivity -ComputerName $ComputerName -TCPPort $WinRMPort -Retries $ServiceRetries -ErrorAction 'Stop' | Out-Null
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 321 -Message "WSMan/WinRM successfully reached at ${ComputerName}:$WinRMPort" -ErrorAction 'SilentlyContinue'

            # probably should turn this into a function ...
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 322 -Message "Sent remote sysprep command to $ComputerName ..." -ErrorAction 'SilentlyContinue'
            $to_sysprep = New-PSSession -ComputerName $ComputerName -Credential $credential
            Invoke-Command -Session $to_sysprep -ScriptBlock {& silcollector publish}
            Start-Sleep -s 60
            Invoke-Command -Session $to_sysprep -ScriptBlock {Start-Process -FilePath 'C:\Windows\System32\Sysprep\sysprep.exe' -ArgumentList '/quiet /oobe /generalize /shutdown'}
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 323 -Message "Remote sysprep command to $ComputerName successful.  Waiting for virtual machine $VMName power state to go to Off ..." -ErrorAction 'SilentlyContinue'

            # The sysprep, if successful, should result in the VM powering off.
            # Wait for power state change before proceeding ...
            #
            # We're going to wait a maximum of 300 retries (~5 minutes)
            $_power_checks = 1
            do {
                Write-Verbose "[INFO] ($(Get-Date)) VM power check #$_power_checks on $VMName ..."
                if ($(Get-VM -VMName $VMName).State -eq 'Off') { break }
                $_power_checks += 1
                Start-Sleep -s 1
            } while ($_power_checks -le 300)

            if ($_power_checks -ge 300) {
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Error' -EventId 323 -Message "Number of retries (300) exceeded waiting for virtual machine $VMName to start.  Aborting." -ErrorAction 'SilentlyContinue'
                Write-Error -Message 'VM did not power off successfully after 300 retries ...' -ErrorAction 'Stop'
            }

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 330 -Message "Mounting $vm_disk_sysprep_path to localhost as read-only disk." -ErrorAction 'SilentlyContinue'

            Mount-VHD -Path $vm_disk_sysprep_path -ReadOnly -Verbose -Confirm:$false
            $MountedVHD = Get-VHDDeviceId -VHDPath $vm_disk_sysprep_path
            $MountedDisk = Get-Disk | Where-Object -Property Path -eq $MountedVHD.pnpdevicepath
            
            # The disk should be configured with the reserve partition and 
            # the system disk.  The system disk should sort to be the at the
            # bottom as the largest partition.
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 331 -Message "Selecting partition for $MountedDisk" -ErrorAction 'SilentlyContinue'
            $SystemToCapture = $MountedDisk | Get-Partition | Select-Object -Last 1

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 332 -Message "Attempting to capture Windows Image" -ErrorAction 'SilentlyContinue'
            
            # TODO: This shouldn't be a static path for future use
            $_wimdestination = "C:\WIMs\$OSType\install-$($(Get-Date).Ticks).wim"
            
            try {
                # TODO: Add check that destinaton folder is there and if not, create it.
                New-WindowsImage -ImagePath $_wimdestination -CapturePath $SystemToCapture.AccessPaths[0] -Name $Name -Description $Description -Verify -ErrorAction Stop
            } catch {
                Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Error' -EventId 333 -Message "Windows Image capture of $VMName failed" -ErrorAction 'SilentlyContinue'
                throw "WIM generation for $OSType was unsuccessful ..."
            }

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 334 -Message "Unmounting $vm_disk_sysprep_path from localhost" -ErrorAction 'SilentlyContinue'
            Dismount-VHD -Path $vm_disk_sysprep_path | Out-Null

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 335 -Message "Reverting virtual machine $VMName to its original disk configuration ..." -ErrorAction 'SilentlyContinue'
            Switch-VMDisks -VMName $VMName -SourceDiskPath $vm_disk_sysprep_path -DestinationDiskPath $vm_disk_original_path | Out-Null

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 336 -Message "Starting virtual machine $VMName to confirm configuration was successful ..." -ErrorAction 'SilentlyContinue'
            Start-VM -VMName $VMName | Out-Null
            
            Test-TCPServiceConnectivity -ComputerName $ComputerName -TCPPort $WinRMPort -Retries $ServiceRetries -ErrorAction 'Stop' | Out-Null
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 200 -Message "Windows Image capture of $VMName completed successfully.  Shutting down guest and exiting." -ErrorAction 'SilentlyContinue'

            Write-Verbose "WIM generation completed ... Shutting down guest and exiting ..."

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 350 -Message "Post-capture cleanup steps starting; Removing differencing disk at $vm_disk_sysprep_path" -ErrorAction 'SilentlyContinue'
            Remove-Item -LiteralPath $vm_disk_sysprep_path -Force -Confirm:$false

            Start-Sleep  -s 10

            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Information' -EventId 351 -Message "Shutting down virtual machine $VMName ..." -ErrorAction 'SilentlyContinue'
            Stop-VM -VMName $VMName
        } catch {
            Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Error' -EventId 398 -Message "Unexpected condition reached. Error details: `n$($Error[0] | Out-String)" -ErrorAction 'SilentlyContinue'
            Write-Error -Message $Error[0].Exception
        }
    } else {
        Write-EventLog -LogName 'OPAW' -Source 'OPAW' -EntryType 'Error' -EventId 399 -Message "Virtual machine $VMName has more than one disk configured.  Aborting operation." -ErrorAction 'SilentlyContinue'
        Write-Error -Message "The selected VM has more than one disk associated with it;  Aborting ..."
    }

}