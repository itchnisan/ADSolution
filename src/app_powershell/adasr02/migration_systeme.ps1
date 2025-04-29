param(
    [switch]$VerboseOutput
)


# Create log folder and dynamic filename
$scriptPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$logDir = "$scriptPath\log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = "$logDir\compare_log_$timestamp.txt"
$VerbosePreference = if ($VerboseOutput) { 'Continue' } else { 'SilentlyContinue' }

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$now][$Level] $Message"
    Add-Content -Path $logPath -Value $logMessage
    if ($VerboseOutput) {
        Write-Host $logMessage
    }
}


# Start logging
Write-Log "=== Script started ==="

# SQL connection parameters
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$global:domainName = "gcm.intra.groupama.fr"
$csvHeader = "GroupName;GUID;Mail;samAccountName;Name"

# Load custom module
Import-Module -Name "$scriptPath\base_func\base_func.psm1" -Force
Write-Log "Module base_func loaded."


 
# Measure execution time
$executionTime = Measure-Command {
    migration
}

Write-Log "Execution Time: $($executionTime.TotalSeconds) seconds" 
Write-Log "=== Script ended ==="
