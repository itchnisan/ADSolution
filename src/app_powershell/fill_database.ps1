﻿$global:domainName = "gcm.intra.groupama.fr"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Include the insert scripts
. "$scriptPath\base_insert\fill_groups.ps1"
. "$scriptPath\base_insert\fill_user.ps1"
. "$scriptPath\base_insert\fill_link_usr_grp.ps1"

# Path to the folder containing exported CSVs
$csvDirectory = Join-Path -Path $PSScriptRoot -ChildPath "data_to_csv"

# Check if the directory exists
if (-Not (Test-Path $csvDirectory)) {
    Write-Host "CSV folder '$csvDirectory' not found." -ForegroundColor Red
    exit
}

# Get all CSV files in the folder
$csvFiles = Get-ChildItem -Path $csvDirectory -Filter "*.csv"

# Keep track of inserted user GUIDs
$insertedUsers = @()

Measure-Command {
    foreach ($csvFile in $csvFiles) {
        # The filename (without extension) is the group's SamAccountName
        $groupName = [System.IO.Path]::GetFileNameWithoutExtension($csvFile.Name)

        # Get group info from Active Directory
        $group = Get-ADGroup -Identity $groupName -Properties SamAccountName, DistinguishedName, ObjectGUID -Server $global:domainName

        if ($group) {
            Write-Host "`nProcessing group: $($groupName)" -ForegroundColor Cyan

            # Insert group into the database
            Insert-Groups -group $group

            # Read user data from the CSV file
            $csvData = Import-Csv -Path $csvFile.FullName -Delimiter ';'

            foreach ($entry in $csvData) {
                # Create a mock user object from CSV data
                $mockUser = [PSCustomObject]@{
                    ObjectGUID     = $entry.GUID
                    SamAccountName = $entry.samAccountName
                    Name           = $entry.Name
                    Mail           = $entry.Mail
                }

                # Check if user was already inserted
                if (-not $insertedUsers.Contains($mockUser.ObjectGUID)) {
                    # Insert the user into the database
                    Insert-User -user $mockUser
                    $insertedUsers += $mockUser.ObjectGUID
                }

                # Create the link between the user and the group
                Insert-link-User-Group -id_group $group.ObjectGUID -id_user $mockUser.ObjectGUID
            }

            Write-Host "→ Group $groupName processed successfully." -ForegroundColor Green
        }
        else {
            Write-Host "⚠ Group '$groupName' not found in Active Directory." -ForegroundColor Yellow
        }
    }
}
