function 480Banner()
{
    Write-Host "Hello SYS480"
}

function 480Connect([string] $server)
{
    $conn = $global:DefaultVIServer
    
    if($conn){
        $msg = "Already Connected to {0}" -f $conn

        Write-Host -ForegroundColor Green $msg
    }else {
        $conn = Connect-VIServer -Server $server
    }
}

Function Get-480Config([string] $config_Path){
    Write-Host "Reading " $config_Path
    $conf = $null
    if(Test-Path $config_Path)
    {
        $conf = (Get-Content -Raw -Path $config_Path | ConvertFrom-Json)
        $msg = "Using Configuration file: {0}" -f $config_Path
        Write-Host -ForegroundColor "Green" $msg
    }else
    {
        Write-Host -ForegroundColor "Yellow" "No Configuration file located"
    }
    return $conf
}

function LinkedClone($conf) {
    try {
        # Get available VMs in the specified folder
        $vmList = Get-VM -Location $conf.vm_folder | Select-Object Name -ExpandProperty Name
 
        # Debug: Print the VM list
        # Write-Host "VM List: $($vmList -join ', ')" -ForegroundColor Cyan
 
        # Check if there are any VMs available
        if ($vmList.Count -eq 0) {
            Write-Host "No VMs found in the specified folder." -ForegroundColor Red
            return
        }
 
        # Display numbered list of VMs
        Write-Host "Available VMs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vmList.Count; $i++) {
            Write-Host "$($i + 1). $($vmList[$i])"
        }
 
        # Prompt user to select a VM by number
        $selectedNumber = Read-Host -Prompt "Enter the number of the VM to clone"
        $selectedIndex = [int]$selectedNumber - 1
 
        # Validate the selected number
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $vmList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected VM name
        $selectedVMName = $vmList[$selectedIndex].Trim()
 
        # Debug: Print the selected VM name
        Write-Host "Selected VM Name: $selectedVMName" -ForegroundColor Cyan
 
        # Validate the selected VM name
        if ([string]::IsNullOrEmpty($selectedVMName)) {
            Write-Host "The selected VM name is null or empty. Please check the VM list." -ForegroundColor Red
            return
        }
 
        # Get the VM object
        $toclone = Get-VM -Name $selectedVMName -ErrorAction Stop
 
        # Get the specified snapshot
        $snapshot = Get-Snapshot -VM $toclone -Name $conf.snapshot -ErrorAction Stop
 
        # Prompt user for the new VM name
        $clonename = Read-Host -Prompt "Enter a name for the new VM"
        $linkedname = "{0}.linked" -f $clonename
 
        # Create the linked clone
        $linkedvm = New-VM -LinkedClone -Name $linkedname -VM $toclone -ReferenceSnapshot $snapshot -VMHost $conf.esxi_host -Datastore $conf.datastore -ErrorAction Stop
        Write-Host "Linked clone created: $linkedname" -ForegroundColor Green
 
        # Ask if the user wants to create a full clone
        $fullClone = Read-Host -Prompt "Do you want to create a full clone? (yes/no)"
        if ($fullClone -eq "yes") {
            # Create the full clone from the linked clone
            $newvm = New-VM -Name $clonename -VM $linkedvm -VMHost $conf.esxi_host -Datastore $conf.datastore -ErrorAction Stop
            Write-Host "Full clone created: $clonename" -ForegroundColor Green
 
            # Create a base snapshot for the full clone
            $newvm | New-Snapshot -Name "Base" -ErrorAction Stop
            Write-Host "Base snapshot created for $clonename" -ForegroundColor Green
 
            # Remove the temporary linked clone
            $linkedvm | Remove-VM -DeletePermanently -Confirm:$false -ErrorAction Stop
            Write-Host "Temporary linked clone removed." -ForegroundColor Green

        } else {
            Write-Host "Full clone creation skipped." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Set-VMNetwork($conf) {
    try {
        # Get available VMs in the specified folder
        $vmList = Get-VM | Select-Object Name -ExpandProperty Name
 
        # Check if there are any VMs available
        if ($vmList.Count -eq 0) {
            Write-Host "No VMs found in the specified folder." -ForegroundColor Red
            return
        }
 
        # Display numbered list of VMs
        Write-Host "Available VMs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vmList.Count; $i++) {
            Write-Host "$($i + 1). $($vmList[$i])"
        }
 
        # Prompt user to select a VM by number
        $selectedNumber = Read-Host -Prompt "Enter the number of the VM to configure network"
        $selectedIndex = [int]$selectedNumber - 1
 
        # Validate the selected number
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $vmList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected VM name
        $selectedVMName = $vmList[$selectedIndex]
 
        # Debug: Print the selected VM name
        Write-Host "Selected VM Name: $selectedVMName" -ForegroundColor Cyan
 
        # Validate the selected VM name
        if ([string]::IsNullOrEmpty($selectedVMName)) {
            Write-Host "The selected VM name is null or empty. Please check the VM list." -ForegroundColor Red
            return
        }
 
        # Get the VM object
        $vm = Get-VM -Name $selectedVMName -ErrorAction Stop
 
        # Get network adapters for the VM
        $networkAdapters = Get-NetworkAdapter -VM $vm -ErrorAction Stop
 
        # Check if there are any network adapters
        if ($networkAdapters.Count -eq 0) {
            Write-Host "No network adapters found for the selected VM." -ForegroundColor Red
            return
        }
 
        # Display numbered list of network adapters
        Write-Host "Available Network Adapters:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $networkAdapters.Count; $i++) {
            Write-Host "$($i + 1). Adapter $($i + 1) - Type: $($networkAdapters[$i].Type), Current Network: $($networkAdapters[$i].NetworkName)"
        }
 
        # Prompt user to select a network adapter by number
        $adapterNumber = Read-Host -Prompt "Enter the number of the network adapter to modify"
        $adapterIndex = [int]$adapterNumber - 1
 
        # Validate the selected adapter number
        if ($adapterIndex -lt 0 -or $adapterIndex -ge $networkAdapters.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($networkAdapters.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected network adapter
        $selectedAdapter = $networkAdapters[$adapterIndex]
 
        # Get available network port groups
        $networkList = Get-VirtualPortGroup | Select-Object Name -ExpandProperty Name
 
        # Check if there are any networks available
        if ($networkList.Count -eq 0) {
            Write-Host "No networks found on the specified host." -ForegroundColor Red
            return
        }
 
        # Display numbered list of networks
        Write-Host "Available Networks:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $networkList.Count; $i++) {
            Write-Host "$($i + 1). $($networkList[$i])"
        }
 
        # Prompt user to select a network by number
        $networkNumber = Read-Host -Prompt "Enter the number of the network to assign"
        $networkIndex = [int]$networkNumber - 1
 
        # Validate the selected network number
        if ($networkIndex -lt 0 -or $networkIndex -ge $networkList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($networkList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected network name
        $selectedNetwork = $networkList[$networkIndex]
 
        # Debug: Print the selected network
        Write-Host "Selected Network: $selectedNetwork" -ForegroundColor Cyan
 
        # Set the new network for the selected network adapter
        Set-NetworkAdapter -NetworkAdapter $selectedAdapter -NetworkName $selectedNetwork -Confirm:$false -ErrorAction Stop
 
        Write-Host "Network adapter $($adapterIndex + 1) updated to '$selectedNetwork' for VM '$selectedVMName'." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Set-VMState($conf) {
    try {
        # Get available VMs in the specified folder
        $vmList = Get-VM | Select-Object Name -ExpandProperty Name
 
        # Debug: Print the VM list
        # Write-Host "VM List: $($vmList -join ', ')" -ForegroundColor Cyan
 
        # Check if there are any VMs available
        if ($vmList.Count -eq 0) {
            Write-Host "No VMs found in the specified folder." -ForegroundColor Red
            return
        }
 
        # Display numbered list of VMs
        Write-Host "Available VMs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vmList.Count; $i++) {
            Write-Host "$($i + 1). $($vmList[$i])"
        }
 
        # Prompt user to select a VM by number
        $selectedNumber = Read-Host -Prompt "Enter the number of the VM to power on/off"
        $selectedIndex = [int]$selectedNumber - 1
 
        # Validate the selected number
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $vmList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected VM name
        $selectedVMName = $vmList[$selectedIndex]
 
        # Debug: Print the selected VM name
        Write-Host "Selected VM Name: $selectedVMName" -ForegroundColor Cyan
 
        # Validate the selected VM name
        if ([string]::IsNullOrEmpty($selectedVMName)) {
            Write-Host "The selected VM name is null or empty. Please check the VM list." -ForegroundColor Red
            return
        }
 
        # Get the VM object
        $vm = Get-VM -Name $selectedVMName -ErrorAction Stop
 
        # Get the current power state
        $currentState = $vm.PowerState
        Write-Host "Current Power State: $currentState" -ForegroundColor Cyan
 
        # Ask the user what action they want to perform
        $action = Read-Host -Prompt "Do you want to power ON or OFF the VM? (on/off)"
 
        if ($action -eq "on") {
            if ($currentState -eq "PoweredOn") {
                Write-Host "The VM is already powered on." -ForegroundColor Yellow
            } else {
                Start-VM -VM $vm -Confirm:$false -ErrorAction Stop
                Write-Host "VM '$selectedVMName' has been powered on." -ForegroundColor Green
            }
        }
        elseif ($action -eq "off") {
            if ($currentState -eq "PoweredOff") {
                Write-Host "The VM is already powered off." -ForegroundColor Yellow
            } else {
                Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop
                Write-Host "VM '$selectedVMName' has been powered off." -ForegroundColor Green
            }
        }
        else {
            Write-Host "Invalid input. Please enter 'on' or 'off'." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function Get-IP($conf) {
    try {
        # Get available VMs in the specified folder
        $vmList = Get-VM | Select-Object Name -ExpandProperty Name
 
        # Check if there are any VMs available
        if ($vmList.Count -eq 0) {
            Write-Host "No VMs found in the specified folder." -ForegroundColor Red
            return
        }
 
        # Display numbered list of VMs
        Write-Host "Available VMs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vmList.Count; $i++) {
            Write-Host "$($i + 1). $($vmList[$i])"
        }
 
        # Prompt user to select a VM by number
        $selectedNumber = Read-Host -Prompt "Enter the number of the VM to get IP details"
        $selectedIndex = [int]$selectedNumber - 1
 
        # Validate the selected number
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $vmList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected VM name
        $selectedVMName = $vmList[$selectedIndex].Trim()
 
        # Debug: Print the selected VM name
        Write-Host "Selected VM Name: $selectedVMName" -ForegroundColor Cyan
 
        # Validate the selected VM name
        if ([string]::IsNullOrEmpty($selectedVMName)) {
            Write-Host "The selected VM name is null or empty. Please check the VM list." -ForegroundColor Red
            return
        }
 
        # Get the VM object
        $vm = Get-VM -Name $selectedVMName -ErrorAction Stop
 
        # Get VM Guest information
        $guest = Get-VMGuest -VM $vm -ErrorAction Stop
 
        # Get network adapters
        $network = Get-NetworkAdapter -VM $vm -ErrorAction Stop
 
        # Iterate through network adapters
        $i = 0
        foreach($adapter in $network){
            $name = $adapter.Name
            $ip = $guest.IPAddress[$i] | Where-Object { $_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' }
            $mac = $adapter.MACAddress
 
            Write-Host -ForegroundColor Cyan "Network Information for $($name)"
            Write-Host -ForegroundColor Cyan "IP Address: $ip"
            Write-Host -ForegroundColor Cyan "MAC Address: $mac"
 
            $i=$i+2
        }
        return $network
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

function New-Network {
    try {
        # Creates a new virtual Switch and port group
        $vswitch = Read-Host "Enter a name for the new virtual switch"
        $vmHost = (Get-VMHost).Name
        $switch = New-VirtualSwitch -VMHost $vmHost -Name $vswitch -ErrorAction Stop
        New-VirtualPortGroup -VirtualSwitch $vswitch -Name $vswitch -ErrorAction Stop
        Write-Host -ForegroundColor Green "The new virtual switch $vswitch was created successfully"
    }
    catch {
        Write-Host -ForegroundColor Red "An error occurred: $_"
    }
}

function Set-IPAddress {
    try {
        # Get available VMs
        $vmList = Get-VM | Select-Object Name -ExpandProperty Name
 
        # Check if there are any VMs available
        if ($vmList.Count -eq 0) {
            Write-Host "No VMs found." -ForegroundColor Red
            return
        }
 
        # Display numbered list of VMs
        Write-Host "Available VMs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $vmList.Count; $i++) {
            Write-Host "$($i + 1). $($vmList[$i])"
        }
 
        # Prompt user to select a VM by number
        $selectedNumber = Read-Host -Prompt "Enter the number of the VM to configure"
        $selectedIndex = [int]$selectedNumber - 1
 
        # Validate the selected number
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $vmList.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmList.Count)." -ForegroundColor Red
            return
        }
 
        # Get the selected VM name
        $selectedVMName = $vmList[$selectedIndex]
 
        # Debug: Print the selected VM name
        Write-Host "Selected VM: $selectedVMName" -ForegroundColor Cyan
 
        # Validate the selected VM name
        if ([string]::IsNullOrEmpty($selectedVMName)) {
            Write-Host "The selected VM name is null or empty. Please check the VM list." -ForegroundColor Red
            return
        }
 
        # Get the VM object
        $vmObject = Get-VM -Name $selectedVMName -ErrorAction Stop
 
        # Prompt for credentials
        $GuestUser = Read-Host -Prompt "Enter guest OS username"
        $GuestPassword = Read-Host -Prompt "Enter guest OS password" -AsSecureString
 
        # Prompt for network configuration
        $IPAddress = Read-Host -Prompt "Enter IP address"
        $SubnetMask = Read-Host -Prompt "Enter subnet mask"
        $Gateway = Read-Host -Prompt "Enter default gateway"
        $NameServer = Read-Host -Prompt "Enter DNS server"
 
 
        # Confirm VM selection and IP configuration
        Write-Host "VM to configure: $selectedVMName" -ForegroundColor Green
        Write-Host "IP Configuration:" -ForegroundColor Green
        Write-Host "  IP Address: $IPAddress" -ForegroundColor Green
        Write-Host "  Subnet Mask: $SubnetMask" -ForegroundColor Green
        Write-Host "  Gateway: $Gateway" -ForegroundColor Green
        Write-Host "  Name Server: $NameServer" -ForegroundColor Green
 
        $confirmation = Read-Host "Proceed with configuration? (Y/N)"
        if ($confirmation -ne "Y" -and $confirmation -ne "y") {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            return
        }
 
        # The commands that will be executed
        $NetshCommand = "netsh interface ip set address name='Ethernet0' static $IPAddress $SubnetMask $Gateway"
        $DnsCommand = "netsh interface ip set dns name='Ethernet0' static $NameServer"

        $fullScript = "$NetshCommand`r`n$DnsCommand"

        # Execute the script using Invoke-VMScript
        Write-Host "Applying network configuration to VM..." -ForegroundColor Cyan
        $result = Invoke-VMScript -VM $vmObject -ScriptText $fullScript -GuestUser $GuestUser -GuestPassword $GuestPassword
 
        # Display the result
        if ($result.ExitCode -eq 0) {
            Write-Host "Network configuration successfully applied to $selectedVMName." -ForegroundColor Green
        }
        else {
            Write-Host "Failed to apply network configuration. Exit code: $($result.ExitCode)" -ForegroundColor Red
            Write-Host "Error output: $($result.ScriptOutput)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}