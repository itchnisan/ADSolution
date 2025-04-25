# SQL connection parameters
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$global:domainName = "gcm.intra.groupama.fr"
$csvHeader = "GroupName;GUID;Mail;samAccountName;Name"

# Determine script path dynamically
$scriptPath = Split-Path -Parent $PSScriptRoot

# Setup log file
$logFilePath = "$scriptPath\logs\sync_log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
New-Item -ItemType Directory -Force -Path "$scriptPath\logs" | Out-Null

function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp][$level] $message"
    Add-Content -Path $logFilePath -Value $logLine
    Write-Host $logLine
}

# Load custom module
Import-Module -Name "$scriptPath\base_func\base_func.psm1" -Force

function compare_file {
    $connectionString = "Server=$server;Database=$database;Integrated Security=True"
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

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

        $contentTable = $table | Select-Object GroupName, GUID, Mail, samAccountName, Name
        $grp = Get-ADGroup -Identity $groupName -Properties SamAccountName, DistinguishedName, ObjectGUID -Server $global:domainName

        if ($table.Rows.Count -eq 0) {
            Write-Log "No users found in DB for group $groupName. Inserting from CSV..."
            Insert-Groups -group $grp
            Insert-List-Users -filteredUsers $contentGroup -groupid $grp.ObjectGUID
            Write-Log "Users from CSV inserted into DB for group $groupName" "SUCCESS"
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
            Write-Log "Aucun utilisateur dans le fichier CSV pour le groupe $groupName" "WARN"
            continue
        }
        if (-not $sqlUsers) {
            Write-Log "Aucun utilisateur en base pour le groupe $groupName" "WARN"
            continue
        }

        $diffList = Compare-Object -ReferenceObject $csvUsers -DifferenceObject $sqlUsers

        foreach ($diff in $diffList) {
            $user = $diff.InputObject
            if ($diff.SideIndicator -eq '<=') {
                Write-Log "Insertion utilisateur $($user.samAccountName) ($($user.GUID)) dans groupe $groupName"
                Insert-User -user @{
                    user_guid      = $user.GUID
                    samAccountName = $user.samAccountName
                    name           = $user.Name
                    email          = $user.Mail
                } -groupid $grp.ObjectGUID
            }
            elseif ($diff.SideIndicator -eq '=>') {
                Write-Log "Suppression lien utilisateur $($user.samAccountName) ($($user.GUID)) du groupe $groupName"
                Delete-Link-User-Group -user_guid $user.GUID -group_guid $grp.ObjectGUID
            }
            else {
                Write-Log "Mise à jour utilisateur $($user.samAccountName) ($($user.GUID)) dans groupe $groupName"
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
    Write-Log "Traitement terminé pour tous les groupes." "INFO"
}

Measure-Command {
    compare_file | ForEach-Object { Write-Output $_ }
} 
