$sqliteDbPath = "$PSScriptRoot\..\..\database\base.db"   # base path
$sqlite3 = "C:\sqlite\sqlite3.exe"          



function Insert-link-User-Group {
    param(
        $id_group,
        $id_user
    )
    

        $sql = "INSERT INTO user_group (user_id,group_id) VALUES ('$id_group', '$id_user');"
        & $sqlite3 $sqliteDbPath $sql
    

    Write-Host "Lien crée."

}