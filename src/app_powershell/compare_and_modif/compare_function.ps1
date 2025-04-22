# Paramètres de connexion SQL
$server = "GCMSKWG105\GCM_INTRANET"
$database = "BINTRA01"
$outputDir = "$PSScriptRoot\output"

# Include the insert scripts
Import-Module -Name "$scriptPath\base_func\base_func.psm1"

function compare_file {
    param (
        [string]$outputDir
    )
    $connectionString = "Server=$server;Database=$database;Integrated Security=True"

    

    $alreadyCompared = @{}
    $identicalGroups = @()

    #load the list of group ad
    $groupList = Get-ChildItem "$PSScriptRoot\"


    # Connection to base
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    foreach ($group in $groupList) {
            $groupClean = $group.Trim()

        #SQL request for each code
        $query = @"
         select g.name,u.id,u.email,u.sam_acount_name,u.name from users u 
                join user_group ug on u.id = ug.user_id
                join groups g on ug.group_id = g.id
                where g.name = '$group.SamAccountName'
"@

        #prepare request + execution + fill table of member
        $command = $connection.CreateCommand()
        $command.CommandText = $query
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null
        
        $contentGroup = Get-Content $group
        $contentTable = Get-Content $table

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