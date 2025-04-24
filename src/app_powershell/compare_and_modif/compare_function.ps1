# SQL connection parameters
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$global:domainName = "gcm.intra.groupama.fr"
$csvHeader = "GroupName;GUID;Mail;samAccountName;Name"

# Determine script path dynamically
$scriptPath = Split-Path -Parent $PSScriptRoot

# Load custom module containing insert/delete functions
Import-Module -Name "$scriptPath\base_func\base_func.psm1" -Force

function compare_file {
    # Build SQL connection string
    $connectionString = "Server=$server;Database=$database;Integrated Security=True"

    # Load CSV files representing AD groups
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"

    # Open SQL connection
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    foreach ($group in $groupList) {
        # Extract group name from file name
        $groupName = [System.IO.Path]::GetFileNameWithoutExtension($group.Name)

        # SQL query to retrieve users from database for this group
        $query = @"
         SELECT u.user_guid as GUID, g.name AS GroupName, u.id, u.email as Mail, u.sam_acount_name as samAccountName, u.name AS Name
         FROM T_ASR_AD_USERS_1 u 
         JOIN T_ASR_AD_USERS_GROUPS_1 ug ON u.id = ug.user_id
         JOIN T_ASR_AD_GROUPS_1 g ON ug.group_id = g.id
         WHERE g.name = '$groupName'
"@

        # Execute SQL query and fill DataTable
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null

        # Load CSV content as text
        # $contentGroup = Get-Content $group.FullName

        $contentGroup = Import-Csv -Path $group.FullName -Delimiter ';' -Encoding default

        # Convert DataTable content to text for comparison
        # Convert SQL result (DataTable) to an array of CSV lines
        $contentTable = $table  | Select-Object GroupName,GUID, Mail, samAccountName, Name #| ConvertTo-Csv -Delimiter ';' -NoTypeInformation
        # Get AD group object
            $grp = Get-ADGroup -Identity $groupName -Properties SamAccountName, DistinguishedName, ObjectGUID -Server $global:domainName

        # If no users found in DB, insert group and users from CSV
        if ($table.Rows.Count -eq 0) {
            Write-Host "No users found in DB for group $groupName. Inserting from CSV..."

            

            # Insert group into database
            Insert-Groups -group $grp

            # Import CSV content and insert users
            #$csvData = Import-Csv -Path "$scriptPath\data_to_csv\$group" -Delimiter ';' -Encoding default
            Insert-List-Users -filteredUsers $contentGroup -groupid $grp.ObjectGUID



            Write-Host "pas bloquer dans l'insert" -ForegroundColor Cyan


            continue
        }   
        
           
        
       # write-host "les content  " $contentGroup  -ForegroundColor Magenta
       # write-host "les content  " $contentTable  -ForegroundColor Red

        # Force un format homogène pour les deux listes
        $csvUsers = $contentGroup | ForEach-Object {
            [PSCustomObject]@{
                GroupName      = $_.GroupName
                GUID           = $_.GUID
                Mail           = $_.Mail
                samAccountName = $_.samAccountName
                Name           = $_.Name
            }
        }

        $sqlUsers = $contentTable | ForEach-Object {
            [PSCustomObject]@{
                GroupName      = $_.GroupName
                GUID           = $_.GUID
                Mail           = $_.Mail
                samAccountName = $_.samAccountName
                Name           = $_.Name
            }
        }

        # Compare CSV content with DB content
        #$diffList = Compare-Object -ReferenceObject $contentGroup -DifferenceObject $contentTable
        $diffList = Compare-Object -ReferenceObject $csvUsers -DifferenceObject $sqlUsers

        write-host "la diff list" -ForegroundColor Magenta
    
        foreach ($diff in $diffList) {
            if ($diff.SideIndicator -eq '<=') {
                # User present in DB but not in CSV → insert into DB
                $user = $diff.InputObject

                Write-Host "Ligne différente trouvée :" `
                    $user.GUID $user.samAccountName $user.Name -ForegroundColor Green

                Insert-User -user @{
                    user_guid      = $user.GUID
                    samAccountName = $user.samAccountName
                    name           = $user.Name
                    email          = $user.Mail
                } -groupid $grp.ObjectGUID
            }
            elseif ($diff.SideIndicator -eq '=>') {
                # User present in CSV but not in DB → delete from DB
                $user = $diff.InputObject
                #Write-Host $user "insert "
               #Delete-User -id_user $user.GUID
            }
        }
    }
    
    # Close DB connection
    $connection.Close()
}

# Measure the execution time of the comparison process
Measure-Command {
    $results = compare_file -outputDir $outputDir
    $results | ForEach-Object { Write-Output $_ }
}
