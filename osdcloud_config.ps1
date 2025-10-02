# osdcloud_config.ps1 - MSP Custom for NinjaOne and Migration

# Prompt for Client Org ID (semi-zero-touch; automate via USB param file for full zero-touch)
$orgId = Read-Host "Enter NinjaOne Client Organization ID"

# Install NinjaOne Agent
Start-Process msiexec -ArgumentList "/i C:\OSDCloud\Automate\Provisioning\NinjaRMMAgent.msi /qn ORGANIZATION_ID=$orgId" -Wait

# Data Restore: Pull encrypted backup from client-segregated storage (e.g., OneDrive/Azure)
$machineName = $env:COMPUTERNAME
$backupUrl = "https://your-msp-storage/$orgId/$machineName/backup.zip"  # Use SAS token for security
Invoke-WebRequest -Uri $backupUrl -OutFile "C:\Temp\backup.zip" -UseBasicParsing
Expand-Archive "C:\Temp\backup.zip" -DestinationPath "C:\Users"  # Restore profiles/files

# Inventory Import: Run NinjaOne script to upload old device's app/settings inventory
Invoke-Expression (Invoke-WebRequest -Uri "https://your-ninja-api/scripts/inventory_import.ps1" -UseBasicParsing).Content

# Domain/Entra ID Join (if not in unattend.xml)
$joinType = Read-Host "Join Domain (D) or Entra ID (E)?"
if ($joinType -eq 'D') {
    Add-Computer -DomainName "clientdomain.com" -Credential (Get-Credential)  # Secure creds prompt
} elseif ($joinType -eq 'E') {
    dsregcmd /join /silent
}

# Cleanup and Reboot
Remove-Item "C:\Temp\backup.zip"
Restart-Computer -Force
