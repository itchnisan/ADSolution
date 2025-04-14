$global:domainName = "gcm.intra.groupama.fr"
$targetOuDn = "OU=DOSI,OU=GROUPES_NORMAUX,OU=GROUPES,OU=CENTRE-MANCHE,DC=gcm,DC=intra,DC=groupama,DC=fr"
$allAdGroups = Get-ADGroup -SearchBase $targetOuDn -Filter * -Server $global:domainName

# Traitement
Measure-Command {
    foreach ($group in $allAdGroups) {
        Write-Host "Traitement du groupe $($group.Name)..." -ForegroundColor Cyan

        $rawMembers = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive -Server $global:domainName

        $filteredUsers = @()
        $alreadySeen = @{}

        foreach ($member in $rawMembers) {
            if ($member.objectClass -eq 'user' -and -not $alreadySeen.ContainsKey($member.samAccountName)) {
                $user = [System.Linq.Enumerable]::FirstOrDefault(
                    $Users_GCM, 
                    [Func[object,bool]]{ param($x) $x.samAccountName -eq $member.samAccountName }
                )
                if ($user) {
                    $filteredUsers += [PSCustomObject]@{
                        GroupName       = $group.DistinguishedName
                        GUID            = $user.ObjectGUID
                        Mail            = $user.Mail
                        samAccountName  = $user.samAccountName
                        Name            = $user.Name
                    }
                    $alreadySeen[$member.samAccountName] = $true
                }
            }
        }

        $csvPath = Join-Path $directoryCsv "$($group.SamAccountName).csv"
        $filteredUsers | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

        Write-Host " → Exporté : $csvPath ($($filteredUsers.Count) utilisateurs)" -ForegroundColor Green
    }
}