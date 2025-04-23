# Configuration SQL Server
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$connectionString = "Server=$server;Database=$database;Integrated Security=True;"

#region Fonctions SQL de base

<#
.SYNOPSIS
Exécute une requête SQL qui retourne une seule valeur (ExecuteScalar)

.PARAMETER query
Requête SQL à exécuter

.RETOUR
Résultat unique (première colonne, première ligne)
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

#region Utilisateurs

<#
.SYNOPSIS
Insère une liste d'utilisateurs dans la base de données.

.PARAMETER filteredUsers
Objet DataTable contenant les colonnes : GUID, samAccountName, Name, Mail.
#>
function Insert-List-Users {
    param($filteredUsers,$groupid)

    Write-Host $filteredUsers
    foreach ($row in $filteredUsers) {
    Write-Host $row
        Insert-User -user @{
            user_guid      = $row.GUID
            samAccountName = $row.samAccountName
            name           = $row.Name
            email          = $row.Mail
        }
        Insert-link-User-Group -user_guid $row.GUID -group_guid $groupid
    }
}

<#
.SYNOPSIS
Insert a single user if they don't already exist.

.PARAMETER user
Object containing: user_guid, samAccountName, name, email
#>
function Insert-User {
    param($user)

    $guid = $user.user_guid
    $sam = $user.samAccountName
    $name = $user.name
    $mail = $user.email

    if (-not (User-Exists -user_guid $guid)) {
        $sql = @"
INSERT INTO T_ASR_AD_USERS_1 (user_guid, sam_acount_name, name, email)
VALUES ('$guid', '$sam', '$name', '$mail');
"@
        Invoke-SqlNonQuery -query $sql
    } else {
        Write-Host "User with GUID $guid already exists. Skipping insertion."
    }
}


#endregion Utilisateurs

#region Groupes

<#
.SYNOPSIS
Insère un groupe unique.

.PARAMETER group
Objet contenant : ObjectGUID, SamAccountName, DistinguishedName
#>
function Insert-Groups {
    param($group)

    $group_guid = $group.ObjectGUID
    $sam_name = $group.SamAccountName
    $dn = $group.DistinguishedName

    $sql = @"
INSERT INTO T_ASR_AD_GROUPS_1 (group_guid, name, dn)
VALUES ('$group_guid', '$sam_name', '$dn');
"@

    Invoke-SqlNonQuery -query $sql
}

#endregion Groupes

#region Lien Utilisateur-Groupe

<#
.SYNOPSIS
Crée un lien utilisateur-groupe via leurs GUIDs.

.PARAMETER user_guid
GUID utilisateur

.PARAMETER group_guid
GUID groupe
#>
function Insert-link-User-Group {
    param(
        [string]$user_guid,
        [string]$group_guid
    )

    $getUserId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $getGroupId = "SELECT id FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$group_guid';"

    $user_id = Invoke-SqlQuery -query $getUserId
    $group_id = Invoke-SqlQuery -query $getGroupId

    if ($user_id -and $group_id) {
        $sql = "INSERT INTO T_ASR_AD_USERS_GROUPS_1 (user_id, group_id) VALUES ($user_id, $group_id);"
        Invoke-SqlNonQuery -query $sql
    }
}

#endregion Lien Utilisateur-Groupe

#region Suppression

<#
.SYNOPSIS
Supprime un utilisateur par GUID
#>
function Delete-User {
    param([string]$user_guid)

    $sql = "DELETE FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    Invoke-SqlNonQuery -query $sql
}

<#
.SYNOPSIS
Supprime un groupe par GUID
#>
function Delete-Group {
    param([string]$group_guid)

    $sql = "DELETE FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$group_guid';"
    Invoke-SqlNonQuery -query $sql
}

<#
.SYNOPSIS
Supprime un lien utilisateur-groupe via leurs GUIDs
#>
function Delete-Link-User-Group {
    param(
        [string]$user_guid,
        [string]$group_guid
    )

    $getUserId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $getGroupId = "SELECT id FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$group_guid';"

    $user_id = Invoke-SqlQuery -query $getUserId
    $group_id = Invoke-SqlQuery -query $getGroupId

    if ($user_id -and $group_id) {
        $sql = "DELETE FROM T_ASR_AD_USERS_GROUPS_1 WHERE user_id = $user_id AND group_id = $group_id;"
        Invoke-SqlNonQuery -query $sql
    }
}

#endregion Suppression

#region Verification
<#
.SYNOPSIS
Check if a user already exists in the database.

.PARAMETER user_guid
The GUID of the user to check.

.RETURN
Returns $true if user exists, otherwise $false.
#>
function User-Exists {
    param([string]$user_guid)

    $query = "SELECT COUNT(*) FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $count = Invoke-SqlQuery -query $query
    return ($count -gt 0)
}
#endregion Verification