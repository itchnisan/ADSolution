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

    
    foreach ($row in $filteredUsers) {

    Write-Host "ligne du user " $row -ForegroundColor Red

        Insert-User -user @{
            user_guid      = $row.GUID
            samAccountName = $row.samAccountName
            name           = $row.Name
            email          = $row.Mail
        } -groupid $groupid
        
    }
}

<#
.SYNOPSIS
Insert a single user if they don't already exist.

.PARAMETER user
Object containing: user_guid, samAccountName, name, email
#>
function Insert-User {
    param(
        [hashtable]$user,
        $groupid
    )

    $guid = $user.user_guid
    $sam = $user.samAccountName
    $name = $user.name
    $mail = $user.email

    Write-Host "Insertion de l'utilisateur :" $guid $sam $name $mail -ForegroundColor Magenta

    if (-not (User-Exists -user_guid $guid)) {
        Write-Host "L'utilisateur n'existe pas encore, insertion en base..." -ForegroundColor Green

        $sql = @"
INSERT INTO T_ASR_AD_USERS_1 (user_guid, sam_acount_name, name, email)
VALUES ('$guid', '$sam', '$name', '$mail');
"@

        Invoke-SqlNonQuery -query $sql
    } else {
        Write-Host "Utilisateur déjà présent : $guid → Aucune insertion." -ForegroundColor Yellow
    }

    if (-not (User-Group-Link-Exists -user_guid $guid -group_guid $groupid)) {
        Write-Host "Création du lien utilisateur-groupe pour $guid ↔ $groupid" -ForegroundColor Cyan
        Insert-link-User-Group -user_guid $guid -group_guid $groupid
    } else {
        Write-Host "Liaison user-groupe déjà existante pour $guid et $groupid" -ForegroundColor DarkGray
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

    if (-not (Group-Exists -group_guid $group_guid)) {
        $sql = @"
INSERT INTO T_ASR_AD_GROUPS_1 (group_guid, name, dn)
VALUES ('$group_guid', '$sam_name', '$dn');
"@
        Invoke-SqlNonQuery -query $sql
    }
    else {
        Write-Host "Group $group_guid already exists. Skipping insertion."
    }
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
    Write-Host "enter in link"
    $getUserId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $getGroupId = "SELECT id FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$group_guid';"

    $user_id = Invoke-SqlQuery -query $getUserId
    $group_id = Invoke-SqlQuery -query $getGroupId

    Write-Host "insert in link" $user_id $group_id
    if ($user_id -and $group_id) {
    
        $sql = "INSERT INTO T_ASR_AD_USERS_GROUPS_1 (user_id, group_id) VALUES ($user_id, $group_id);"
        Invoke-SqlNonQuery -query $sql
    }else{
        Write-Warning " link non insérer pour :" $user_guid $group_guid
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

    #get the id from the guid
    $sqlGetId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid';"
    $id_user = Invoke-SqlScalar -query $sqlGetId

    if ($null -ne $id_user) {
        #delete link where user_id = id
        $sqlDeleteLinks = "DELETE FROM T_ASR_AD_USER_GROUPS WHERE user_id = $id_user;"
        Invoke-SqlNonQuery -query $sqlDeleteLinks

        #delete
        $sqlDeleteUser = "DELETE FROM T_ASR_AD_USERS_1 WHERE id_user = $id_user;"
        Invoke-SqlNonQuery -query $sqlDeleteUser

        Write-Output "Utilisateur supprimé avec succès (id_user = $id_user)"
    } else {
        Write-Warning "Aucun utilisateur trouvé pour le GUID : $user_guid"
    }
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

        $checkLinks = "SELECT COUNT(*) FROM T_ASR_AD_USERS_GROUPS_1 WHERE user_id = $user_id;"
        $linkCount = Invoke-SqlNonQuery -query $checkLinks

        if ($linkCount -eq 0) {
            $deleteUser = "DELETE FROM T_ASR_AD_USERS_1 WHERE id = $user_id;"
            Invoke-SqlNonQuery -query $deleteUser
            Write-Output "Utilisateur supprimé car plus lié à aucun groupe (id = $user_id)."
        } else {
            Write-Output "Lien supprimé, mais utilisateur toujours associé à d'autres groupes."
        }
     } else {
        Write-Warning "Utilisateur ou groupe introuvable."
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

    $query = "SELECT COUNT(*) FROM T_ASR_AD_USERS_1 WHERE user_guid = '$user_guid' "
    $count = Invoke-SqlQuery -query $query
    Write-Host $count 
    return ($count -gt 0)
}

function Group-Exists {
    param([string]$group_guid)
    $query = "SELECT COUNT(*) FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$group_guid';"
    $count = Invoke-SqlQuery -query $query
    return ($count -gt 0)
}

function User-Group-Link-Exists {
    param($user_guid, $group_guid)

    $query = @"
SELECT COUNT(*) 
FROM T_ASR_AD_USERS_1 u
JOIN T_ASR_AD_USERS_GROUPS_1 ug ON u.id = ug.user_id
JOIN T_ASR_AD_GROUPS_1 g ON ug.group_id = g.id
WHERE u.user_guid = '$user_guid' AND g.group_guid = '$group_guid'
"@

    $result = Invoke-SqlQuery -query $query
    return ($result -gt 0)
}

#endregion Verification


#region Update User

<#
.SYNOPSIS
Updates an existing user in the database with new information.

.PARAMETER user
Object containing: user_guid, samAccountName, name, email

.RETURN
Updates the user in the database if there are changes.
#>
function Update-User {
    param(
        [hashtable]$user
    )

    $guid = $user.user_guid
    $sam = $user.samAccountName
    $name = $user.name
    $mail = $user.email

    Write-Host "Updating user:" $guid $sam $name $mail -ForegroundColor Cyan

    $sql = @"
UPDATE T_ASR_AD_USERS_1 
SET sam_acount_name = '$sam', name = '$name', email = '$mail' 
WHERE user_guid = '$guid';
"@
    
    Invoke-SqlNonQuery -query $sql
}

#endregion Update User
