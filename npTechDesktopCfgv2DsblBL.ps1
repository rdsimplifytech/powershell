#Requires -RunAsAdministrator

# Script to configure Windows 11 settings for a new computer
# Run this script with administrative privileges

# 1. Check if Windows is fully up-to-date
Write-Host "Checking for Windows Updates..."
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
if ($SearchResult.Updates.Count -eq 0) {
    Write-Host individua"Windows is fully up-to-date."
} else {
    Write-Host "Found $($SearchResult.Updates.Count) pending updates. Installing..."
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $SearchResult.Updates
    $Downloader.Download()
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $SearchResult.Updates
    $Result = $Installer.Install()
    if ($Result.ResultCode -eq 2) {
        Write-Host "Updates installed successfully. Reboot may be required."
    } else {
        Write-Host "Update installation failed with code: $($Result.ResultCode)"
    }
}

# 2. Set Time Zone to Eastern Standard Time
Write-Host "Setting time zone to Eastern Standard Time..."
try {
    Set-TimeZone -Id "Eastern Standard Time" -ErrorAction Stop
    Write-Host "Time zone set successfully."
}
catch {
    Write-Host "Error setting time zone: $_"
}

# 3. Disable BitLocker on the system drive
Write-Host "Checking and disabling BitLocker..."
try {
    $BitLockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    if ($BitLockerStatus.ProtectionStatus -eq "On") {
        Write-Host "BitLocker is enabled on C:. Disabling..."
        Disable-BitLocker -MountPoint "C:" -ErrorAction Stop
        Write-Host "BitLocker disabled successfully."
    } else {
        Write-Host "BitLocker is not enabled on C:."
    }
}
catch {
    Write-Host "Error disabling BitLocker: $_"
}

# Function to check and set registry value
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Value,
        [string]$Type = "DWORD"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Host "Successfully set $Name in $Path to $Value"
    }
    catch {
        Write-Host "Error setting $Name in $Path : $_"
    }
}

# 4. System -> Notifications -> Additional Settings
# Turn off all notification options including Welcome Experience, Setup Suggestions, and Tips
Write-Host "Configuring Notification settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0

# 5. Personalization -> Start
# Disable "Show recommendations for tips..."
Write-Host "Configuring Start menu settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0

# Disable Phone Link (Phone Thing)
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0

# 6. Personalization -> Taskbar
# Disable Copilot, Task View, and Widgets
Write-Host "Configuring Taskbar settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
# Check if Widgets setting is supported before applying
if (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue) {
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
} else {
    Write-Host "TaskbarDa (Widgets) setting not found, skipping..."
}

# Set Taskbar alignment to Left
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0

# 7. Privacy & Security -> General
# Disable "Show me suggested..." and "Let apps show me personalized..."
Write-Host "Configuring Privacy settings..."
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

# 8. Control Panel -> Power
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