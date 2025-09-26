#Requires -RunAsAdministrator

# Script to configure Windows 11 settings for a new computer
# Run this script with administrative privileges

# Function to check and set registry value
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Value,
        [string]$Type = "DWORD"
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

# 1. System -> Notifications -> Additional Settings
# Turn off all 3 options
Write-Host "Configuring Notification settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0

# 2. Personalization -> Start
# Disable "Show recommendations for tips..."
Write-Host "Configuring Start menu settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0

# Disable Phone Link (Phone Thing)
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0

# 3. Personalization -> Taskbar
# Disable Copilot, Task View, and Widgets
Write-Host "Configuring Taskbar settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

# Set Taskbar alignment to Left
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0

# 4. Privacy & Security -> General
# Disable "Show me suggested..." and "Let apps show me personalized..."
Write-Host "Configuring Privacy settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

# 5. Control Panel -> Power
# Disable Sleep on plugged in, 30 minutes on battery
# Screen off at 15 minutes plugged in, 5 on battery
# Disable Fast Startup
Write-Host "Configuring Power settings..."
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 30
powercfg /change monitor-timeout-ac 15
powercfg /change monitor-timeout-dc 5
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0

Write-Host "All settings have been configured successfully."