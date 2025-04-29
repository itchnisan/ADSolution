$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$connectionString = "Server=$server;Database=$database;Integrated Security=True;"

$scriptPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)



#region Fonctions SQL de base

<#
.SYNOPSIS
Exécute une requête SQL sans retour (INSERT, UPDATE, DELETE, etc.)

.PARAMETER query
Requête SQL à exécuter
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


#endregion Fonctions SQL

#region App

<#
.SYNOPSIS


.PARAMETER 
#>

function App-IsMigrate {
    param([string] $app_name)
    
        $sql = @"
        select flag_migrate from T_ASR_AD_TRANSCO_1 where app_name ='$app_name'
"@

        $flag = Invoke-SqlNonQuery -query $sql

        return($flag)
}




<#
.SYNOPSIS


.PARAMETER 
#>

function Get-CodeTrans {
    param([string] $app_name)
    
        $sql = @"
        select codetrans from T_ASR_AD_TRANSCO_1 where app_name ='$app_name'
"@

        $code = Invoke-SqlNonQuery -query $sql

        return($code)
}
#endregion App



#region user

<#
.SYNOPSIS


.PARAMETER 
#>

function Get-StatusUser {
    param([string] $app_name,
          [string] $user_guid)
    
        $sql = @"
        select count(*) from T_ASR_AD_TRANSCO_1 transco 
        join dbo.TEPHABL1 hab on transco.codetrans = hab.CODETRANS
        where transco.app_name ='$app_name' and hab.IDENTFICHPERS = '$user_guid'
"@

        $count = Invoke-SqlNonQuery -query $sql

        return($count -gt 0)
}

<#
.SYNOPSIS


.PARAMETER 
#>

function Get-UserInAD{
    param([string] $user_guid)
    

    $result = 0
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"
    foreach($group in $groupList){
        
        $data = Import-Csv -Path $group.FullName -Delimiter ';' -Encoding default
        $result += $data | Where-Object { $_.GUID -eq $user_guid.ToString() }


    }

    return($result -gt 0)
}


function Delete-User {
    param([string]$user_guid)

    #get the id from the guid
    $sqlGetId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $id_user = Invoke-SqlNonQuery -query $sqlGetId

    if ($null -ne $id_user) {
        #delete link where user_id = id
        $sqlDeleteLinks = "DELETE FROM T_ASR_AD_USER_GROUPS WHERE user_id = $id_user;"
        Invoke-SqlNonQuery -query $sqlDeleteLinks

        #delete
        $sqlDeleteUser = "DELETE FROM T_ASR_AD_USERS_1 WHERE id_user = $id_user;"
        Invoke-SqlNonQuery -query $sqlDeleteUser

        Write-Output "user delete with succes (id_user = $id_user)"
    } else {
        Write-Warning "no user found for guid : $user_guid"
    }
}

#endregion user