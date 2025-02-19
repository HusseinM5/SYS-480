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
 
        # Debug: Print the VM list
        Write-Host "VM List: $($vmList -join ', ')" -ForegroundColor Cyan
 
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
 
        # Get available network port groups
        $networkList = Get-VirtualNetwork | Select-Object Name -ExpandProperty Name
 
        # Debug: Print the network list
        # Write-Host "Available Networks: $($networkList -join ', ')" -ForegroundColor Cyan
 
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
 
        # Get the network adapter of the VM
        $networkAdapter = Get-NetworkAdapter -VM $vm -ErrorAction Stop
 
        # Validate network adapter existence
        if (-not $networkAdapter) {
            Write-Host "No network adapter found for the selected VM." -ForegroundColor Red
            return
        }
 
        # Set the new network for the VM
        Set-NetworkAdapter -NetworkAdapter $networkAdapter -NetworkName $selectedNetwork -Confirm:$false -ErrorAction Stop
 
        Write-Host "Network adapter updated to '$selectedNetwork' for VM '$selectedVMName'." -ForegroundColor Green
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