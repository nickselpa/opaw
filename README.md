# Overview
Out Popped A WIM (OPAW) is a PowerShell project that is designed to manage
the Windows Updates for a base system image.  OPAW will then capture the 
WIM and record the updates applied on each version.

This project uses [Semantic Versioning](http://semver.org) as its versioning convention.

## Host Dependencies
- Windows Server 2012 R2 or later
- Windows Management Framework 5.0 or later
- Chocolatey

#### Required Host Windows Features
- Hyper-V

#### Windows Virtual Machine Guest Requirements
- Windows Server 2008 R2 SP1 or later
- Windows Management Framework 5.0 or later
- WinRM

#### Required Chocolatey Packages
- sysinternals (core function)
- winscp (extras)

## Installation
TODO: Make a DSC script to support the following steps from scratch
- Install Hyper-V Role
- Create folders for VM configuration and VM hard disk locations
- Install Chocolatey
- Install the winscp and sysinternals choco packages
- Install the OPAW module
- (optional goal) Create seed vanilla VM(s)
- Pop WIMs for days

## Operation
The scope of OPAW is to provide an appliance-like all-in-one location to 
create updated Windows Images (WIM).  This is accomplished using a Hyper-V
host and the PowerShell tooling available across multiple Microsoft products
(such as virtualization and system image management) to deliver fully updated
Windows Images at the ready. 

OPAW serves two major functions:

- Running Windows Update Agent remotely against a remote target
- Sysprep remote target and capture Windows Image with native Windows tooling

Please see the sample script provided with the project/module for an example of
how OPAW's tools are leveraged.

## Functions

### Common

**Invoke-PSExecSession** - A PowerShell wrapper for invoking PsExec64.exe

**Invoke-RemoteWindowsUpdate** - Uses PS Remoting to copy a Windows Update script
to the remote target and invoke that script on the system for updates.

**Invoke-RemoteSysprepCapture** - Specifying a virtual machine that has one virtual
disk, the guest will have the following actions taken:

- Guest VM will be shut down
- Guest VM's system disk will be the source of the new differencing disk
- Guest VM will power back on using differencing disk
- Guest VM will receive remote sysprep command with shutdown
- When powered off, differencing disk will be mounted to OPAW Host
- Mounted disk will be used for Windows Image capture
- When successful, the guest VM will be reconfigured to use its original disk
- Guest VM will checked that it is able to successfully start and boot to OS
- On successful boot, delete differencing disk
- Guest VM gets shut down

**Switch-VMDisks** - Switch the source disk with the specified destation disk
for a Hyper-V virtual machine

**Get-VMDiskConfiguration** - Capture a configuration snapshot of the Hyper-V
virtual machine's disk configuration

**Get-VHDDeviceId** - Collects the OS Disk ID of a mounted VHD/VHDX

**Test-TCPServiceConnectivity** - Checks to see if a TCP service is available
within a set number of retries

### Extras
**Send-WinSCPFile** - [Dependent on: WinSCP] Sends a file to a remote server
using WinSCP through the provided library

### Initialize
**Register-OPAWLogLocation** - If absent from system, creates a custom Event Log
location to send native Windows log messages.

## Configurable Settings
TODO: Implement environment variable configuration in initialize script
NOTE: This is not live in the current 1.0 release

$env:OPAWROOT - root folder for OPAW resources

$env:OPAWLOGS - default text logging location for OPAW

$env:OPAWWIMS - default folder location for captured WIMs

$env:OPAWCFG - default configuration folder for OPAW (may not be required [TBD])

