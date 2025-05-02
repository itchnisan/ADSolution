$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# SQL connection parameters
$server = "DCMSKWG102\GCM_INTRANET"
$database = "BINTRA01"
$global:domainName = "gcm.intra.groupama.fr"

function fill_transco {
    $connectionString = "Server=$server;Database=$database;Integrated Security=True"
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    $appListe = Import-Csv -Path "$scriptPath\csvtransco.csv" -Delimiter ';' -Encoding Default

    foreach ($app in $appListe) {
        $AppName = $app.AppName.Replace("'", "''")
        $Path = $app.Path.Replace("'", "''")
        $MotherApp = $app.MotherApp.Replace("'", "''")
        $Migrate = $app.Migrate

   
        $queryGroup = @"
SELECT id FROM T_ASR_AD_GROUPS_1 WHERE name = '$AppName'
"@
        $commandGroup = $connection.CreateCommand()
        $commandGroup.CommandText = $queryGroup
        $groupId = $commandGroup.ExecuteScalar()

      
        if ($groupId -eq $null) {
            $groupId = "NULL"
        }

    
        $query1 = @"
INSERT INTO T_ASR_AD_TRANSCO_APP_1 (app_name, path_app, flag_migrate, mother_app, group_id)
VALUES ('$AppName', '$Path', '$Migrate', '$MotherApp', $groupId);
SELECT SCOPE_IDENTITY();
"@
        $command1 = $connection.CreateCommand()
        $command1.CommandText = $query1
        $appid = $command1.ExecuteScalar()

        if ($appid -ne $null) {
            # 3. Insérer les codes liés
            $codeList = $app.codetrans -split ','

            foreach ($code in $codeList) {
                $codeTrimmed = $code.Trim().Replace("'", "''")
                if ($codeTrimmed -ne "") {
                    $query2 = @"
INSERT INTO T_ASR_AD_TRANSCO_CODE_1 (app_id, codetrans)
VALUES ($appid, '$codeTrimmed')
"@
                    $command2 = $connection.CreateCommand()
                    $command2.CommandText = $query2
                    $command2.ExecuteNonQuery() | Out-Null
                }
            }
        } else {
            Write-Warning "Échec de l'insertion de l'application : $AppName"
        }
    }

    $connection.Close()
}


Measure-Command {
    fill_transco
}
