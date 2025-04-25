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

function compare_file {
    $connectionString = "Server=$server;Database=$database;Integrated Security=True"
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    Write-Log "SQL connection opened."

    foreach ($group in $groupList) {
        $groupName = [System.IO.Path]::GetFileNameWithoutExtension($group.Name)
        Write-Log "Processing group: $groupName"



        $query = @"
         SELECT u.user_guid as GUID, g.name AS GroupName, u.id, u.email as Mail, u.sam_acount_name as samAccountName, u.name AS Name
         FROM T_ASR_AD_USERS_1 u 
         JOIN T_ASR_AD_USERS_GROUPS_1 ug ON u.id = ug.user_id
         JOIN T_ASR_AD_GROUPS_1 g ON ug.group_id = g.id
         WHERE g.name = '$groupName'
"@

        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null

        $contentGroup = Import-Csv -Path $group.FullName -Delimiter ';' -Encoding default
        $contentTable = $table | Select-Object GroupName,GUID, Mail, samAccountName, Name

        $grp = Get-ADGroup -Identity $groupName -Properties SamAccountName, DistinguishedName, ObjectGUID -Server $global:domainName

        if ($table.Rows.Count -eq 0) {
            Write-Log "No users found in DB for $groupName. Inserting from CSV..." "WARN"
            Insert-Groups -group $grp
            Insert-List-Users -filteredUsers $contentGroup -groupid $grp.ObjectGUID
            Write-Log "Insert completed for group: $groupName"
        }

        $csvUsers = $contentGroup | ForEach-Object {
            [PSCustomObject]@{
                GroupName      = $_.GroupName
                GUID           = $_.GUID
                Mail           = $_.Mail
                samAccountName = $_.samAccountName
                Name           = $_.Name
            }
        }

        $sqlUsers = $contentTable | ForEach-Object {
            [PSCustomObject]@{
                GroupName      = $_.GroupName
                GUID           = $_.GUID
                Mail           = $_.Mail
                samAccountName = $_.samAccountName
                Name           = $_.Name
            }
        }

        if (-not $csvUsers) {
            Write-Log "No users in CSV for group $groupName. Skipping." "WARN"
            continue
        }

        if (-not $sqlUsers) {
            Write-Log "No users in SQL for group $groupName. Skipping." "WARN"
            continue
        }

        $diffList = Compare-Object -ReferenceObject $csvUsers -DifferenceObject $sqlUsers

        foreach ($diff in $diffList) {
            $user = $diff.InputObject

            if ($diff.SideIndicator -eq '<=') {
                Write-Log "User in CSV but not DB: $($user.samAccountName)"
                Insert-User -user @{
                    user_guid      = $user.GUID
                    samAccountName = $user.samAccountName
                    name           = $user.Name
                    email          = $user.Mail
                } -groupid $grp.ObjectGUID
            }
            elseif ($diff.SideIndicator -eq '=>') {
                Write-Log "User in DB but not CSV (deleting): $($user.samAccountName)"
                Delete-Link-User-Group -user_guid $user.GUID -group_guid $grp.ObjectGUID
            }
            else {
                Write-Log "User needs update: $($user.samAccountName)"
                Update-User -user @{
                    user_guid      = $user.GUID
                    samAccountName = $user.samAccountName
                    name           = $user.Name
                    email          = $user.Mail
                }
            }
        }
    }

    $connection.Close()
    Write-Log "SQL connection closed." 
}
 
# Measure execution time
$executionTime = Measure-Command {
    compare_file
}

Write-Log "Execution Time: $($executionTime.TotalSeconds) seconds" 
Write-Log "=== Script ended ==="
