# EndpointDriverCompliance.ps1
param (
    [Parameter(Mandatory = $true)]
    [string]$ReportPath = "C:\Scripts\DriverReport.csv",

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -or $_ -match '^[a-zA-Z]:\\.*\.json$' })]
    [string]$DeprecatedDriversJson = "C:\Scripts\DeprecatedDrivers.json"  # Example: [{"Name":"OldDriver","Version":"1.0"}]
)

# Validate input files
if (-not (Test-Path $DeprecatedDriversJson)) {
    Write-Error "The file '$DeprecatedDriversJson' does not exist. Please provide a valid path."
    exit 1
}

try {
    # Load deprecated list
    $deprecated = Get-Content $DeprecatedDriversJson | ConvertFrom-Json
} catch {
    Write-Error "Failed to load or parse the deprecated drivers JSON file: $_"
    exit 1
}

try {
    # Get drivers
    $drivers = Get-WmiObject Win32_PnPSignedDriver | Select DeviceName, DriverVersion, DriverDate, InfName
} catch {
    Write-Error "Failed to retrieve driver information: $_"
    exit 1
}

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

try {
    # Export report
    $results | Export-Csv -Path $ReportPath -NoTypeInformation -Force
    Write-Host "Report successfully generated at $ReportPath."
} catch {
    Write-Error "Failed to export the report to '$ReportPath': $_"
    exit 1
}

# Optional: Alert (integrate with NinjaOne or O365)
$highRiskCount = ($results | Where-Object Risk -ne 'Low Risk').Count
Write-Host "High-risk drivers detected: $highRiskCount"
if ($highRiskCount -gt 0) {
    Write-Warning "Please review the report for high-risk or deprecated drivers."
}