# EndpointDriverCompliance.ps1
param (
    [string]$ReportPath = "C:\Scripts\DriverReport.csv",
    [string]$DeprecatedDriversJson = "C:\Scripts\DeprecatedDrivers.json"  # Example: [{"Name":"OldDriver","Version":"1.0"}]
)

# Load deprecated list
$deprecated = Get-Content $DeprecatedDriversJson | ConvertFrom-Json

# Get drivers
$drivers = Get-WmiObject Win32_PnPSignedDriver | Select DeviceName, DriverVersion, DriverDate, InfName

# Scan and score
$results = foreach ($driver in $drivers) {
    $isDeprecated = $deprecated | Where-Object { $driver.DeviceName -match $_.Name -and $driver.DriverVersion -eq $_.Version }
    $ageScore = if ($driver.DriverDate -lt (Get-Date).AddYears(-3)) { "High Risk" } else { "Low Risk" }
    [PSCustomObject]@{
        DeviceName = $driver.DeviceName
        Version = $driver.DriverVersion
        Date = $driver.DriverDate
        Risk = if ($isDeprecated) { "Deprecated" } else { $ageScore }
    }
}

# Export report
$results | Export-Csv -Path $ReportPath -NoTypeInformation

# Optional: Alert (integrate with NinjaOne or O365)
Write-Host "Report generated at $ReportPath. High-risk drivers: $($results | Where-Object Risk -ne 'Low Risk' | Measure-Object).Count"