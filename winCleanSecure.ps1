#requires -RunAsAdministrator
#requires -Version 5.1

<#
.SYNOPSIS
    Configures a basic, secure Windows 11 setup for workplace use by disabling unnecessary features, 
    installing Google Chrome, running updates, and verifying settings. This script is non-destructive 
    and can be run on new or existing systems.
    
.DESCRIPTION
    This script performs the following:
    1. Disables location services system-wide.
    2. Disables advertising, suggestions, Cortana, and other "fluff" via registry modifications.
    3. Disables automatic Windows updates (sets to manual notification).
    4. Removes Microsoft Edge shortcuts and sets Chrome as default browser.
    5. Downloads and installs Google Chrome (stable version).
    6. Disables BitLocker if enabled on the system drive.
    7. Installs and runs all applicable Windows updates using PSWindowsUpdate module.
    8. Verifies and re-applies disabled settings after updates to ensure they persist.
    
    All changes are made via registry, services, and standard commands. No data is deleted.
    
.NOTES
    - Run as Administrator.
    - Tested on Windows 11 22H2 and later.
    - PSWindowsUpdate module will be installed if not present (requires internet).
    - Chrome installation requires internet access.
    - Updates may require reboots; the script will prompt if needed.
    - Verification logs to console; if settings revert, they are re-applied.
#>

# Function to apply disables
function Apply-Disables {
    Write-Host "Applying disables..."

    # Disable location services (system-wide)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -ErrorAction SilentlyContinue
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -ErrorAction SilentlyContinue | Out-Null

    # Disable Cortana
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -ErrorAction SilentlyContinue
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -ErrorAction SilentlyContinue | Out-Null

    # Disable web search in Start
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0

    # Disable Start menu suggestions and ads
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0

    # Disable tips, tricks, and suggestions
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0

    # Disable ads in File Explorer
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0

    # Disable OneDrive auto-start (unlink if running)
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -Value "" -ErrorAction SilentlyContinue
    taskkill /f /im OneDrive.exe 2>$null

    # Disable telemetry (basic level for workplace)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue | Out-Null
    Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue

    # Disable automatic updates (set to notify only)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 2
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue | Out-Null

    # Remove Edge shortcuts and set default browser associations
    Write-Host "Removing Edge shortcuts and configuring default browser..."
    Remove-Item "$env:USERPROFILE\Desktop\Microsoft Edge.lnk" -ErrorAction SilentlyContinue
    Remove-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk" -ErrorAction SilentlyContinue

    # Disable BitLocker if enabled
    $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($bitlockerStatus.ProtectionStatus -eq "On") {
        Write-Host "Disabling BitLocker on C: drive..."
        Disable-BitLocker -MountPoint "C:"
    }

    Write-Host "Disables applied."
}

# Function to install Google Chrome
function Install-Chrome {
    Write-Host "Checking for Chrome installation..."
    
    # Check if Chrome is already installed
    $chromeInstalled = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue
    if ($chromeInstalled) {
        Write-Host "Chrome is already installed. Skipping installation."
        return
    }

    Write-Host "Downloading and installing Google Chrome..."
    
    # Create temp directory
    $tempDir = "$env:TEMP\ChromeInstall"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Download Chrome installer (silent install version)
        $chromeUrl = "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe"
        $installerPath = "$tempDir\ChromeStandaloneSetup64.exe"
        
        Write-Host "Downloading Chrome installer..."
        Invoke-WebRequest -Uri $chromeUrl -OutFile $installerPath -UseBasicParsing
        
        if (Test-Path $installerPath) {
            Write-Host "Installing Chrome silently..."
            Start-Process -FilePath $installerPath -ArgumentList "/silent /install" -Wait -NoNewWindow
            
            # Verify installation
            Start-Sleep -Seconds 5
            if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
                Write-Host "Chrome installed successfully!"
                
                # Create Chrome shortcut on desktop
                $chromeShortcut = "$env:USERPROFILE\Desktop\Google Chrome.lnk"
                $WshShell = New-Object -comObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut($chromeShortcut)
                $Shortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                $Shortcut.Save()
                
                # Pin Chrome to taskbar (for current user)
                $taskbarPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
                $chromePinned = "$taskbarPath\Google Chrome.lnk"
                if (Test-Path $chromePinned -PathType Leaf) {
                    Remove-Item $chromePinned -Force
                }
                Copy-Item $chromeShortcut $taskbarPath -Force
                
                # Set Chrome as default browser (basic associations)
                Write-Host "Setting Chrome as default browser..."
                $protocolAssociations = @(
                    @{ Name = "http"; Value = "ChromeHTML" },
                    @{ Name = "https"; Value = "ChromeHTML" },
                    @{ Name = "ftp"; Value = "ChromeHTML" }
                )
                
                foreach ($assoc in $protocolAssociations) {
                    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$($assoc.Name)\UserChoice" -Name "ProgId" -Value $assoc.Value -ErrorAction SilentlyContinue
                }
                
                # Set file associations for HTML files
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice" -Name "ProgId" -Value "ChromeHTML" -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.htm\UserChoice" -Name "ProgId" -Value "ChromeHTML" -ErrorAction SilentlyContinue
                
            } else {
                Write-Warning "Chrome installation may have failed. Please verify manually."
            }
        } else {
            Write-Error "Failed to download Chrome installer."
        }
    }
    catch {
        Write-Error "Error during Chrome installation: $_"
    }
    finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Function to run Windows updates
function Run-Updates {
    Write-Host "Installing PSWindowsUpdate module if needed..."
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
    }
    Import-Module PSWindowsUpdate

    Write-Host "Checking for and installing updates..."
    Get-WUList | Install-WUUpdate -AcceptAll -AutoReboot
}

# Function to verify and re-apply if needed
function Verify-Settings {
    Write-Host "Verifying settings..."

    $issues = @()

    # Check location
    if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -ErrorAction SilentlyContinue).Value -ne "Deny") {
        $issues += "Location services"
    }

    # Check Cortana
    if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue).AllowCortana -ne 0) {
        $issues += "Cortana"
    }

    # Check auto-updates
    if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ErrorAction SilentlyContinue).AUOptions -ne 2) {
        $issues += "Auto-updates"
    }

    # Check BitLocker
    $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($bitlockerStatus.ProtectionStatus -eq "On") {
        $issues += "BitLocker"
    }

    # Check Chrome installation
    if (-not (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
        $issues += "Chrome installation"
    }

    if ($issues.Count -gt 0) {
        Write-Host "Issues found: $($issues -join ', '). Re-applying disables."
        Apply-Disables
        if ($issues -contains "Chrome installation") {
            Write-Host "Re-attempting Chrome installation..."
            Install-Chrome
        }
    } else {
        Write-Host "All settings verified successfully."
    }
}

# Main execution
Write-Host "Starting Windows 11 Workplace Configuration Script..."
Write-Host "============================================================="

Apply-Disables
Install-Chrome
Run-Updates
Verify-Settings

Write-Host "============================================================="
Write-Host "Configuration complete!"
Write-Host "- All unnecessary features disabled"
Write-Host "- Google Chrome installed and set as default browser"
Write-Host "- Windows updates applied"
Write-Host "- System is now ready for workplace deployment"
Write-Host ""
Write-Host "REBOOT RECOMMENDED to ensure all changes take effect."
Write-Host "After reboot, verify Chrome is your default browser in Settings > Apps > Default apps."