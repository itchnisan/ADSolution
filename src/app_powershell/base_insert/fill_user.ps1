
$sqliteDbPath = "..\database\base.db"   # base path
$sqlite3 = ".\sqlite3.exe"                



function Insert-User {
    param(
        $user
    )
   
        $user_guid = $user.ObjectGUID
        $user_Sam_name = $user.samAccountName
        $user_name = $user.Name 
        $user_email = $user.Mail

        $sql = "INSERT INTO users (id,sam_acount_name ,name,email) VALUES ('$user_guid', '$user_Sam_name','$user_name','$user_email');"
        & $sqlite3 $sqliteDbPath $sql
    }

    Write-Host "Les users sont bien insérés."

}