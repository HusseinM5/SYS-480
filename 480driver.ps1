Import-Module '480-utils' -Force
#Call The Banner Function
480Banner
$conf=Get-480Config -config_Path "/home/champuser/Desktop/SYS-480/480.json"
480Connect -Server $conf.vcenter_server


$options = Read-Host -Prompt "Select a function:
1. Linked Clone
2. Network Adapter
3. VM State
"

switch ($options) {
    '1' {
        Clear-Host
        LinkedClone -conf $conf
    }
    '2' {
        Clear-Host
        Set-VMNetwork -conf $conf
    }
    '3' {
        Clear-Host
        Set-VMState -conf $conf
    }
    default {
        Write-Host -ForegroundColor Red "Invalid option!"
    }
}