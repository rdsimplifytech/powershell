# osdcloud_config.ps1 - Custom MSP Config for NinjaOne Integration

# Install NinjaOne Agent Silently (use env vars for multi-tenancy)
$orgId = Read-Host "Enter Client Organization ID"  # Prompt tech for client-specific ID (semi-zero-touch)
Start-Process msiexec -ArgumentList "/i C:\OSDCloud\Automate\Provisioning\NinjaRMMAgent.msi /qn ORGANIZATION_ID=$orgId" -Wait

# Inventory and Data Restore Trigger (post-OS install, via NinjaOne policy)
# Assume old device backup stored in secure cloud (e.g., OneDrive link from NinjaOne custom field)
$machineName = $env:COMPUTERNAME
$backupUrl = "https://your-secure-storage/$orgId/$machineName/backup.zip"  # Encrypted, client-segregated
Invoke-WebRequest -Uri $backupUrl -OutFile "C:\Temp\backup.zip"
Expand-Archive "C:\Temp\backup.zip" -DestinationPath "C:\Users"  # Restore user data

# Apply NinjaOne Policies: App installs, compliance (trigger via agent)
# Example: Run Ninja script for inventory import
Invoke-Expression (Invoke-WebRequest -Uri "https://your-ninja-api/scripts/inventory_import.ps1").Content

# Entra ID/Domain Join (if not in unattend.xml)
if ($env:EntraJoin -eq 'Yes') { dsregcmd /join /silent }  # Use env vars from params

# Cleanup and Reboot
Remove-Item "C:\Temp\backup.zip"
Restart-Computer -Force
