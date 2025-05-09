﻿$sqliteDbPath = "$PSScriptRoot\..\..\database\base.db"   # path for the SQLite base 
$sqlite3 = "C:\sqlite\sqlite3.exe"                        # path for sqlite3.exe

#region Users

<#
.SYNOPSIS
Insert a unique user 

.PARAMETER user
Object user wich contains property  ObjectGUID, samAccountName, Name, Mail.

.EXEMPLE
Insert-User -user $user
#>
function Insert-User {
    param(
        $user
    )
   
    $user_guid = $user.ObjectGUID
    $user_Sam_name = $user.samAccountName
    $user_name = $user.Name 
    $user_email = $user.Mail

    $sql = "INSERT INTO users (id, sam_acount_name, name, email) VALUES ('$user_guid', '$user_Sam_name','$user_name','$user_email');"
    & $sqlite3 $sqliteDbPath $sql

    
}

<#
.SYNOPSIS
Insert an all list of user 

.PARAMETER filteredUsers
List wich contains users with column GUID, samAccountName, Name, Mail.

.EXEMPLE
Insert-List-Users -filteredUsers $filteredUsers
#>
function Insert-List-Users {
    param(
        $filteredUsers
    )
    
    foreach ($row in $filteredUsers.Rows) {
        $user_guid = $row["GUID"]
        $user_Sam_name = $row["samAccountName"]
        $user_name = $row["Name"]
        $user_email = $row["Mail"]
        
        $sql = "INSERT INTO users (id, sam_acount_name, name, email) VALUES ('$user_guid', '$user_Sam_name','$user_name','$user_email');"
        & $sqlite3 $sqliteDbPath $sql
    }

    
}

#endregion Users


#region Groupes

<#
.SYNOPSIS
Insert a unique group 

.PARAMETER group
Object group wich contains : ObjectGUID, SamAccountName, DistinguishedName.

.EXEMPLE
Insert-Groups -group $group
#>
function Insert-Groups {
    param(
        $group
    )
    
    $group_guid = $group.ObjectGUID
    $group_Sam_name = $group.SamAccountName
    $group_dn = $group.DistinguishedName

    $sql = "INSERT INTO groups (id, name, dn) VALUES ('$group_guid', '$group_Sam_name','$group_dn');"
    & $sqlite3 $sqliteDbPath $sql

    
}

#endregion Groupes


#region link User-Groupe

<#
.SYNOPSIS
Create a link in the table user-group

.PARAMETER id_group
GUID of the group.

.PARAMETER id_user
GUID of the user.

.EXEMPLE
Insert-link-User-Group -id_group $groupId -id_user $userId
#>
function Insert-link-User-Group {
    param(
        $id_group,
        $id_user
    )
    
    $sql = "INSERT INTO user_group (user_id, group_id) VALUES ('$id_user', '$id_group');"
    & $sqlite3 $sqliteDbPath $sql

   
}

#endregion link User-Groupe
