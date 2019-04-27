#Requires -Version 5
#Requires -RunAsAdministrator

## Event ID Grouping for OPAW
##     0 - 199: Remote Windows Updates Statuses
##   200 - 399: Remote Sysprep and DISM Statuses
##   400 - 599: Undefined
##   600 - 799: Undefined
##   800 - 999: Undefined
## 1000 - 1199: Undefined

## Specific Event IDs
##    0: [Info] Remote Windows Updates Successful with restart
##    1: [Info] Remote Windows Updates Successful with no restart required
##    2: [Error] Remote Updates were successfully 
##  200: Remote System Image Capture Successful

Function Register-OPAWLogLocation {
    [CmdletBinding()]
    param()
    ## TODO: Make folder structure for OPAW assets
    ## TODO: Check and manage system environment variables for OPAW
    if (-not ($(Get-EventLog -List).Log -contains 'OPAW')) {
        Write-Verbose 'No log location found for OPAW; Creating OPAW event log ...'
        New-EventLog -LogName 'OPAW' -Source 'OPAW' 
        Limit-EventLog -LogName 'OPAW'-OverflowAction 'OverwriteAsNeeded' -MaximumSize 40mb
    }
}