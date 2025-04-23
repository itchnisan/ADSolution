# Paramètres de connexion SQL
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$global:domainName = "gcm.intra.groupama.fr"

$scriptPath = Split-Path -Parent $PSScriptRoot

# Include the insert scripts
Import-Module -Name "$scriptPath\base_func\base_func.psm1"  -Force

function compare_file {

    $connectionString = "Server=$server;Database=$database;Integrated Security=True"

    

    $alreadyCompared = @{}
    $identicalGroups = @()

    #load the list of group ad
    $groupList = Get-ChildItem "$scriptPath\data_to_csv"

    
    
    # Connection to base
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    foreach ($group in $groupList) {
       
       $groupName = [System.IO.Path]::GetFileNameWithoutExtension($group.Name)
        
       
        #SQL request for each code
        $query = @"
         SELECT g.name AS group_name, u.id, u.email, u.sam_acount_name, u.name AS user_name
                from T_ASR_AD_USERS_1 u 
                join T_ASR_AD_USERS_GROUPS_1 ug on u.id = ug.user_id
                join T_ASR_AD_GROUPS_1 g on ug.group_id = g.id
                where g.name = '$groupName'
"@

        #prepare request + execution + fill table of member
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        
        $adapter.Fill($table) | Out-Null



        $contentGroup = Get-Content $group.FullName
        

        $contentTable = $table | ForEach-Object {
            "$($_.group_name),$($_.id),$($_.email),$($_.sam_acount_name),$($_.user_name)"
        }

        if ($table.Rows.Count -eq 0) {
            Write-Host "Aucun utilisateur trouvé en base pour le groupe $groupName. Insertion depuis le fichier CSV..."
                $grp = Get-ADGroup -Identity $groupName -Properties SamAccountName, DistinguishedName, ObjectGUID -Server $global:domainName
                
                Insert-Groups -group $grp
                $csvData = Import-Csv -Path  "$scriptPath\data_to_csv\$group" -Delimiter ';'
                
                Insert-List-Users -filteredUsers $csvData -groupid $grp.ObjectGUID
                
            continue
        }


        
       

        $diffList = Compare-Object -ReferenceObject $contentGroup -DifferenceObject $contentTable
        foreach ($diff in $diffList) {
             if ($diff.SideIndicator -eq '<=') {
                 
                 $user = $diff.InputObject
                 Delete-User -id_user $user.GUID

             }elseif($diff.SideIndicator -eq '=>'){
                 $user = $diff.InputObject
                 Insert-User -id_user $user
            
             }

        }


    }

    $connection.Close()
}

$results = compare_file -outputDir $outputDir
$results | ForEach-Object { Write-Output $_ }