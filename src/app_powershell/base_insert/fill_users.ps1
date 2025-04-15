
$sqliteDbPath = "$PSScriptRoot\..\..\database\base.db"   # base path
$sqlite3 = "C:\sqlite\sqlite3.exe"               



function Insert-List-Users {
    param(
        $filteredUsers
    )
    
    foreach ($user in $filteredUsers.Rows) {
        $user_guid = $row["GUID"]  # id of the object unique
        $user_Sam_name = $row["samAccountName"]
        $user_name = $row["Name"]  
        $user_email = $row["Mail"]  
        

        $sql = "INSERT INTO users (id,sam_acount_name ,name,email) VALUES ('$user_guid', '$user_Sam_name','$user_name','$user_email');"
        & $sqlite3 $sqliteDbPath $sql
    }

    Write-Host "Les users sont bien insérés."

}