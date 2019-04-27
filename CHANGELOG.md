# Change Log
All notable changes will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
* Patching changelog based off of source machine and KB's applied to an image
* Convert project into a proper PowerShell module
* Documentation (comment-based help) for Send-WinSCPFile
* Add environment variable creation to opaw-initialize
* [Lower Priority] Make the Windows Update script payload a reusable function
* Add functionality to add multiple indeces to a WIM at creation
 * This would facilitate having Server and Server Core on the same WIM instead
   of stacking multiple files with a single index for each deployment model.

## [v1.0.0] - 2016-12-07
### Added
- This is the initial release of the project
- Initial CHANGELOG for project
- Initial README for project
- Includes the following functions:
 - Get-VMCaptureNotes
 - Get-VMDiskConfiguration
 - Switch-VMDisks
 - Test-TCPServiceConnectivity
 - Get-VHDDeviceId
 - Invoke-PSExecSession
 - Invoke-RemoteWindowsUpdate
 - Invoke-RemoteSysprepCapture
- Sample script using the project is provided

### Changed
- Nothing this release

### Deprecated
- Nothing this release

### Removed
- Nothing this release

### Fixed
- Nothing this release

### Security
- Nothing this release