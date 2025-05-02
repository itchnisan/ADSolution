$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$connectionString = "Server=$server;Database=$database;Integrated Security=True;"

$scriptPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

#region SQL Functions

<#
.SYNOPSIS
Executes a SQL command that does not return any result (e.g., INSERT, UPDATE, DELETE).

.PARAMETER query
The SQL command to execute.
#>
function Invoke-SqlNonQuery {
    param ([string]$query)

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query

    $connection.Open()
    $command.ExecuteNonQuery()
    $connection.Close()
}

<#
.SYNOPSIS
Executes a SQL command and returns a single scalar result.

.PARAMETER query
The SQL query to execute.
#>
function Invoke-SqlQuery {
    param ([string]$query)

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query

    $connection.Open()
    $result = $command.ExecuteScalar()
    $connection.Close()

    return $result
}

#endregion SQL Functions

#region App

<#
.SYNOPSIS
Returns the migration flag of a specific application.

.PARAMETER app_name
The name of the application.
#>
function Get-AppIsMigrate {
    param([string] $app_name)

    $sql = @"
SELECT flag_migrate FROM T_ASR_AD_TRANSCO_1 WHERE app_name = '$app_name'
"@

    $flag = Invoke-SqlQuery -query $sql

    return $flag
}

<#
.SYNOPSIS
Returns the transaction code (codetrans) for a given application.

.PARAMETER app_name
The name of the application.
#>
function Get-CodeTrans {
    param([string] $app_name)

    $sql = @"
SELECT codetrans FROM T_ASR_AD_TRANSCO_1 WHERE app_name = '$app_name'
"@

    $code = Invoke-SqlQuery -query $sql

    return $code
}

#endregion App

#region User

<#
.SYNOPSIS
Inserts a user into the TEPHABL1 table.

.PARAMETER codetrans
The transaction code of the application.

.PARAMETER user_guid
The unique identifier of the user.
#>
function Add-UserInDB {
    param(
        [string] $codetrans,
        [string] $user_guid
    )

    Write-Host "Inserting user:" $user_guid -ForegroundColor Magenta

    $sql = @"
INSERT INTO TEPHABL1 (IDENTFICHPERS, CODETRANS)
VALUES ('$user_guid', '$codetrans');
"@

    Invoke-SqlNonQuery -query $sql
}

<#
.SYNOPSIS
Checks if a user is already present in the TEPHABL1 table for a given application.

.PARAMETER app_name
The name of the application.

.PARAMETER user_guid
The unique identifier of the user.
#>
function Get-StatusUser {
    param(
        [string] $app_name,
        [string] $user_guid
    )

    $sql = @"
SELECT COUNT(*) FROM T_ASR_AD_TRANSCO_1 transco
JOIN dbo.TEPHABL1 hab ON transco.codetrans = hab.CODETRANS
WHERE transco.app_name = '$app_name' AND hab.IDENTFICHPERS = '$user_guid'
"@

    $count = Invoke-SqlQuery -query $sql

    return ($count -gt 0)
}

<#
.SYNOPSIS
Checks whether a user is present in any of the exported AD group CSV files.

.PARAMETER user_guid
The unique identifier of the user.
#>
function Get-UserInAD {
    param([string] $user_guid)

    $result = 0
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"
    foreach ($group in $groupList) {
        $data = Import-Csv -Path $group.FullName -Delimiter ';' -Encoding default
        $result += $data | Where-Object { $_.GUID -eq $user_guid.ToString() }
    }

    return ($result -gt 0)
}

<#
.SYNOPSIS
Deletes a user from the database if they are no longer present in the associated AD group.

.PARAMETER user_guid
The unique identifier of the user.

.PARAMETER group
The group file (CSV) to check against.
#>
function Delete-UserIfNotInGroup {
    param(
        [string] $user_guid
    )

    

    $sql = @"
SELECT * FROM TEPHABL1 WHERE IDENTFICHPERS = '$user_guid'
"@

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $sql
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $table = New-Object System.Data.DataTable
    $adapter.Fill($table) | Out-Null
    $connection.Close()

    $resultInDB = $table | Where-Object { $_.IDENTFICHPERS -eq $user_guid }

    if (-not(Get-UserInAD -user_guid $user_guid) -and $resultInDB) {
        $sqlDeleteUser = "DELETE FROM TEPHABL1 WHERE IDENTFICHPERS = '$user_guid';"
        Invoke-SqlNonQuery -query $sqlDeleteUser

        return 1
    }
    return 0
}

#endregion User
