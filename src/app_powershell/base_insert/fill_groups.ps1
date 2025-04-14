$sqliteDbPath = "..\database\base.db"   # base path
$sqlite3 = ".\sqlite3.exe"                



function Insert-Groups {
    param(
        $group
    )
    
        $group_guid = $group.ObjectGUID
        $group_Sam_name = $group.SamAccountName
        $group_dn = $group.DistinguishedName

        $sql = "INSERT INTO users (id,name,dn) VALUES ('$$group_guid', '$group_Sam_name','$group_dn');"
        & $sqlite3 $sqliteDbPath $sql
    

    Write-Host "Les users sont bien insérés."

}