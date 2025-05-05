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
Function Invoke-SqlQuery {
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory)]
        [string]$Query,
        [hashtable]$Parameters = @{}
    )

    BEGIN {
        $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        # Parameterized Query
        foreach ($key in $Parameters.Keys) {
            [void]$command.Parameters.AddWithValue($key, $Parameters[$key])
        }

        $connection.Open()
    }

    PROCESS {
        try {
            # ExecuteScalar pour les requêtes qui retournent une seule valeur
            $result = $command.ExecuteScalar()
            return $result
        }
        catch {
            Write-Error "Error executing SQL query: $_"
            return $null
        }
    }

    END {
        $connection.Close()
    }
}

<#
.SYNOPSIS
    Exécute une requête SQL sans retour (INSERT, UPDATE, DELETE, etc.)

.PARAMETER query
    Requête SQL à exécuter

.RETOUR
    Pas de retour (Nil)
#>
Function Invoke-SqlNonQuery {
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory)]
        [string]$Query,
        [hashtable]$Parameters = @{}
    )

    BEGIN {
        $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        # Parameterized Query
        foreach ($key in $Parameters.Keys) {
            [void]$command.Parameters.AddWithValue($key, $Parameters[$key])
        }

        $connection.Open()
    }

    PROCESS {
        try {
            $rowsAffected = $command.ExecuteNonQuery()
            return $rowsAffected
        }
        catch {
            Write-Error "Error executing SQL non-query: $_"
            return 0
        }
    }

    END {
        $connection.Close()
    }
}
#endregion Fonctions SQL

#region Utilisateurs

<#
.SYNOPSIS
Insère une liste d'utilisateurs dans la base de données.

.PARAMETER filteredUsers
Objet DataTable contenant les colonnes : GUID, samAccountName, Name, Mail.
#>
Function Import-SQLUsersList { # TODO: Changer Insert-List-Users par Import-SQLUsersList, idem pour Insert-User en Import-SQLUser dans les autres scripts
    Param(
        [Parameter(Mandatory)]
        $FilteredUsers,
        [Parameter(Mandatory)]
        $GroupId
    )
  


    foreach ($user in $FilteredUsers) {
    Import-SQLUser -User $user -GroupId $GroupId
    }

}

Function Import-SQLUser {
    PARAM(
        [Parameter(Mandatory = $true)]
        $User,
        [string]$GroupId
    )

    PROCESS {
        Write-Host ("Checking if user [{0} {1} {2} {3}] needs to be inserted" -f $User.guid, $User.sam, $User.name, $User.mail) -ForegroundColor Magenta

        if (-not (Assert-SQLUser -Guid $User.guid)) {
            Write-Host ("User {0} is not present within the DB, inserting..." -f $User.name)

            $Parameters = @{
                "@Guid"           = $User.guid
                "@SamAccountName" = $User.sam
                "@Name"           = $User.name
                "@Mail"           = if ($User.mail) { $User.mail } else { [DBNull]::Value }
            }

            $sql = @"
INSERT INTO T_ASR_AD_USERS_1 (user_guid, sam_acount_name, name, email)
VALUES (@Guid, @SamAccountName, @Name, @Mail);
"@

            try {
                Invoke-SqlNonQuery -Query $sql -Parameters $Parameters
            }
            catch {
                Write-Error "Erreur lors de l'insertion de $($User.guid) : $_"
                return
            }

            
        } else {
            Write-Host ("Utilisateur déjà présent : {0} → Aucune insertion." -f $User.guid) -ForegroundColor Yellow 
        }
        if (-not (Assert-SQLUserGroupLink -UserGuid $User.guid -GroupGuid $GroupId)) {
                Write-Host "Création du lien utilisateur-groupe pour $($User.guid) ↔ $GroupId" -ForegroundColor Cyan
                Create-UserGroupLink -UserGuid $User.guid -GroupGuid $GroupId
            } else {
                Write-Host "Liaison user-groupe déjà existante pour $($User.guid) et $GroupId" -ForegroundColor DarkGray
            }
    }
}


#endregion Utilisateurs

#region Groupes

function Import-Group {
    <#
    .SYNOPSIS
        Insère un groupe Active Directory dans la base de données.

    .DESCRIPTION
        Cette fonction vérifie si un groupe existe dans la base de données. Si ce n'est pas le cas,
        elle insère le groupe en utilisant ses informations AD : GUID, SamAccountName, DN.

    .PARAMETER group
        Objet groupe AD contenant les propriétés ObjectGUID, SamAccountName et DistinguishedName.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $group
    )

    try {
        $GroupId = $group.ObjectGUID
        $sam_name = $group.SamAccountName
        $dn = $group.DistinguishedName

        if (-not (Check-GroupExistence -GroupId $GroupId)) {
            $sql = @"
INSERT INTO T_ASR_AD_GROUPS_1 (group_guid, name, dn)
VALUES (@GroupId, @SamName, @DN)
"@
            $Parameters = @{
                "@GroupId" = $GroupId
                "@SamName" = $sam_name
                "@DN" = $dn
            }
            
            Invoke-SqlNonQuery -Query $sql -Parameters $Parameters
            Write-Host "Group $sam_name inserted successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Group $sam_name already exists. Skipping insertion." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Error in Import-Group: $_"
    }
}
#endregion Groupes

#region Lien Utilisateur-Groupe

function Create-UserGroupLink {
    <#
    .SYNOPSIS
        Crée un lien entre un utilisateur et un groupe dans la base de données.

    .DESCRIPTION
        Récupère les IDs internes de l'utilisateur et du groupe depuis leurs GUIDs, puis crée une
        entrée dans la table de liaison si les deux existent.

    .PARAMETER UserGuid
        GUID de l'utilisateur.

    .PARAMETER GroupGuid
        GUID du groupe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserGuid,

        [Parameter(Mandatory = $true)]
        [string]$GroupGuid
    )

   
    begin {   
    }
  
    process {
    Write-Host "GUID = "$UserGuid  " ett" $GroupGuid
    $userId  = Get-EntityIdByGuid -TableName "T_ASR_AD_USERS_1" -GuidColumn "user_guid"  -GuidValue $UserGuid
    $groupId = Get-EntityIdByGuid -TableName "T_ASR_AD_GROUPS_1" -GuidColumn "group_guid" -GuidValue $GroupGuid
        Write-Host "Tentative de liaison user_id=$userId avec group_id=$groupId" -ForegroundColor Cyan

        if ($userId -and $groupId) {
            $sql = "INSERT INTO T_ASR_AD_USERS_GROUPS_1 (user_id, group_id) VALUES (@UserId, @GroupId);"
            $params = @{
                "@UserId"  = $userId
                "@GroupId" = $groupId
            }
            Invoke-SqlNonQuery -Query $sql -Parameters $params
        } else {
            Write-Warning "Liaison échouée : ID utilisateur ou groupe introuvable (UserGuid=$UserGuid, GroupGuid=$GroupGuid)."
        }
    }
}

function Get-EntityIdByGuid {
    param (
         [string]$TableName,
         [string]$GuidColumn,
         [string]$GuidValue
    )

    Write-Host ">>> Entrée dans Get-EntityIdByGuid"
    $query = "SELECT id FROM $TableName WHERE $GuidColumn = @Guid;"
    $params = @{ "@Guid" = $GuidValue }

    try {
        $result = Invoke-SqlQuery -Query $query -Parameters $params
        
    } catch {
        Write-Error "ERREUR SQL : $_"
        return $null
    }

    if ($result) {
        return $result
    } else {
        Write-Warning "Aucun résultat trouvé pour $GuidValue"
        return $null
    }
}




#endregion Lien Utilisateur-Groupe

#region Suppression

function Remove-User {
    <#
    .SYNOPSIS
        Supprime un utilisateur de la base de données à partir de son GUID.

    .PARAMETER user_guid
        GUID de l'utilisateur à supprimer.
    #>
    [CmdletBinding()]
    param([string]$UserGuid)

    begin {
        $sqlGetId = "SELECT id FROM T_ASR_AD_USERS_1 WHERE user_guid = '$UserGuid';"
        $id_user_result = Invoke-SqlQuery -query $sqlGetId
        $id_user = if ($id_user_result.Rows.Count -gt 0) { $id_user_result.Rows[0]["id"] } else { $null }
    }

    process {
        if ($null -ne $id_user) {
            $sqlDeleteUser = "DELETE FROM T_ASR_AD_USERS_1 WHERE id = $id_user;"
            Invoke-SqlNonQuery -query $sqlDeleteUser
            Write-Output "User deleted with success (id_user = $id_user)"
        } else {
            Write-Warning "No user found for guid: $user_guid"
        }
    }

    end {}
}

function Remove-Group {
    <#
    .SYNOPSIS
        Supprime un groupe de la base de données à partir de son GUID.

    .PARAMETER group_guid
        GUID du groupe à supprimer.
    #>
    [CmdletBinding()]
    param([string]$GroupId)

    begin {
        $sql = "DELETE FROM T_ASR_AD_GROUPS_1 WHERE group_guid = '$GroupId';"
    }

    process {
        Invoke-SqlNonQuery -query $sql
    }

    end {}
}

function Remove-UserGroupLink {
    <#
    .SYNOPSIS
        Supprime un lien entre un utilisateur et un groupe.
        Supprime également l'utilisateur si celui-ci ne possède plus aucun lien.

    .PARAMETER user_guid
        GUID de l'utilisateur.

    .PARAMETER group_guid
        GUID du groupe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserGuid,

        [Parameter(Mandatory = $true)]
        [string]$GroupGuid
    )

    begin {
    }

    process {

        $userId  = Get-EntityIdByGuid -TableName "T_ASR_AD_USERS_1" -GuidColumn "user_guid"  -GuidValue $UserGuid
        $groupId = Get-EntityIdByGuid -TableName "T_ASR_AD_GROUPS_1" -GuidColumn "group_guid" -GuidValue $GroupGuid

        if ($userId -and $groupId) {
            $sql = "DELETE FROM T_ASR_AD_USERS_GROUPS_1 WHERE user_id = $userId AND group_id = $groupId;"
            Invoke-SqlNonQuery -query $sql

            $checkLinks = "SELECT COUNT(*) AS C FROM T_ASR_AD_USERS_GROUPS_1 WHERE user_id = $userId;"
            $linkCount_result = Invoke-SqlQuery -query $checkLinks

            if ($linkCount_result -eq 0) {
                $deleteUser = "DELETE FROM T_ASR_AD_USERS_1 WHERE id = $userId;"
                Invoke-SqlNonQuery -query $deleteUser
                Write-Output "User deleted because they had 0 links with groups (id = $userId)."
            } else {
                Write-Output "Link deleted but user still in other groups."
            }
        } else {
            Write-Warning "User or group don't exist."
        }
    }

    end {}
}

#endregion Suppression

#region Vérification

function Assert-SQLUser {
    <#
    .SYNOPSIS
        Vérifie si un utilisateur existe dans la base de données.

    .PARAMETER Guid
        GUID de l'utilisateur.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    begin {
        $query = "SELECT COUNT(*) FROM T_ASR_AD_USERS_1 WHERE user_guid = @Guid"
        $params = @{ "@Guid" = $Guid }
    }

    process {
        $count = Invoke-SqlQuery -Query $query -Parameters $params
        return ($count -gt 0)
    }

    end {}
}


function Check-GroupExistence {
    <#
    .SYNOPSIS
        Vérifie si un groupe existe dans la base de données.

    .PARAMETER GroupId
        GUID du groupe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupId
    )

    try {
        $query = "SELECT COUNT(*) FROM T_ASR_AD_GROUPS_1 WHERE group_guid = @GroupId"
        $Parameters = @{
            "@GroupId" = $GroupId
        }
        
        $count = Invoke-SqlQuery -Query $query -Parameters $Parameters
        return ($count -gt 0)
    }
    catch {
        Write-Error "Error in Check-GroupExistence for GroupId $GroupId : $_"
        return $false
    }
}

function Assert-SQLUserGroupLink {
    <#
    .SYNOPSIS
        Vérifie si un lien entre un utilisateur et un groupe existe dans la base de données.

    .PARAMETER UserGuid
        GUID de l'utilisateur.

    .PARAMETER GroupGuid
        GUID du groupe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserGuid,

        [Parameter(Mandatory)]
        [string]$GroupGuid
    )

    begin {
        $query = @"
SELECT COUNT(*) AS C
FROM T_ASR_AD_USERS_1 u
JOIN T_ASR_AD_USERS_GROUPS_1 ug ON u.id = ug.user_id
JOIN T_ASR_AD_GROUPS_1 g ON ug.group_id = g.id
WHERE u.user_guid = @UserGuid AND g.group_guid = @GroupGuid
"@

        $parameters = @{
            "@UserGuid"  = $UserGuid
            "@GroupGuid" = $GroupGuid
        }
    }

    process {
        $count = Invoke-SqlQuery -Query $query -Parameters $parameters
        return ($count -gt 0)
    }

    end {}
}

#endregion Vérification

#region Update User

function Update-ExistingUser {
    <#
    .SYNOPSIS
        Met à jour les informations d'un utilisateur dans la base de données.

    .PARAMETER user
        Objet utilisateur avec les propriétés user_guid, samAccountName, name, email.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$User
    )

    begin {
        $guid = $User.user_guid
        $sam = $User.samAccountName
        $name = $User.name
        $mail = $User.email

        Write-Host "Updating user:" $guid $sam $name $mail -ForegroundColor Cyan

        $sql = @"
UPDATE T_ASR_AD_USERS_1 
SET sam_acount_name = '$sam', name = '$name', email = '$mail' 
WHERE user_guid = '$guid';
"@
    }

    process {
        Invoke-SqlNonQuery -query $sql
    }

    end {}
}

#endregion Update User
