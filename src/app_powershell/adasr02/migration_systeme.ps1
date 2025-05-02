param(
    [switch]$VerboseOutput
)


# Create log folder and dynamic filename
$scriptPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module -Name "$scriptPath\migration_func\migration_func.psm1" -Force


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

function Check-Migration{
    param($user,
          $app)

    #Delete user if is in database (TEPHABL1) but not in ad group   

    if(Delete-UserIfNotInGroup -user_guid $user.ObjectGUID -eq 1){
        
        Write-Log "user" $user.Name "has been delete because not in ad"

    }
    

    #if app isn't migrate 
    if(Get-AppIsMigrate -app_name $app -eq 0){

        Write-Log "app :" $app.Name "isn't migrate"
        #cette fonction est à réaliser 
        $codeList = Get-CodeOfApp -app $app 
        
        #if user is present in transco and habiltation table
        if(Get-StatusUser -app_name $app -user_guid $user.ObjectGUID){

            Write-Log "user :" $user.Name "already present in the transco and habilitations table"
        

        }else{
            #add user and is code in TEPHABL1
            Write-Log "add code for user :" $user.Name
            foreach($code in $codeList){
                Add-UserInDB -codetrans $code -user_guid $user.ObjectGUID
            }
        }

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
