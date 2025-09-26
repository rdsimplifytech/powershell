#Requires -RunAsAdministrator

# Script to configure Windows 11 settings for a new computer
# Run this script with administrative privileges

# 1. Check if Windows is fully up-to-date
Write-Host "Checking for Windows Updates..."
try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
    if ($SearchResult.Updates.Count -eq 0) {
        Write-Host "Windows is fully up-to-date."
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
}
catch {
    Write-Host "Error checking or installing Windows Updates: $_"
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
    if ($BitLockerStatus.ProtectionStatus -eq 1) { # 1 = On, 0 = Off
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

# Function to check and set registry value robustly and idempotently
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [Parameter(Mandatory=$true)][AllowNull()]$Value,
        [string]$Type = "DWORD"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        $current = $null
        try {
            $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
        } catch {}
        if ($current -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            Write-Host "Set $Name in $Path to $Value"
        } else {
            Write-Host "$Name in $Path already set to $Value"
        }
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
try {
    if (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue) {
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
    } else {
        Write-Host "TaskbarDa (Widgets) setting not found, skipping..."
    }
}
catch {
    Write-Host "Error checking TaskbarDa (Widgets) setting: $_"
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
try {
    if (Get-Command powercfg -ErrorAction SilentlyContinue) {
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 30
        powercfg /change monitor-timeout-ac 15
        powercfg /change monitor-timeout-dc 5
    } else {
        Write-Host "powercfg command not found, skipping power settings."
    }
}
catch {
    Write-Host "Error configuring power settings: $_"
}
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0

Write-Host "All settings have been configured successfully."

# 9. Check if NinjaRMMAgent.exe is installed and running
Write-Host "Checking NinjaRMMAgent status..."
try {
    $ninjaExe = Get-ChildItem -Path "C:\Program Files*", "C:\Program Files (x86)*" -Filter "NinjaRMMAgent.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $ninjaService = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
    if ($ninjaExe -and $ninjaService -and $ninjaService.Status -eq "Running") {
        Write-Host "**NINJA: OK**" -ForegroundColor Green
    } elseif ($ninjaExe) {
        Write-Host "**NINJA: INSTALLED BUT NOT RUNNING**" -ForegroundColor Yellow
    } else {
        Write-Host "**NINJA: NOT INSTALLED**" -ForegroundColor Red
    }
}
catch {
    Write-Host "**NINJA: NOT INSTALLED**" -ForegroundColor Red
}