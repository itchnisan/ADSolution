$global:domainName = "gcm.intra.groupama.fr"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptPath\base_insert\fill_groups.ps1"
Import-Module "$scriptPath\base_insert\fill_users.ps1"
Import-Module "$scriptPath\base_insert\fill_link_usr_grp.ps1"



$targetOuDn = "OU=DOSI,OU=GROUPES_NORMAUX,OU=GROUPES,OU=CENTRE-MANCHE,DC=gcm,DC=intra,DC=groupama,DC=fr"
$allAdGroups = Get-ADGroup -SearchBase $targetOuDn -Filter * -Server $global:domainName

# Traitement
Measure-Command {
    foreach ($group in $allAdGroups) {
        Write-Host "Traitement du groupe $($group.Name)..." -ForegroundColor Cyan

        #call insert group
        Insert-Groups -group $group

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
                    Insert-link-User-Group -id_group $group.ObjectGUID -id_user $user.ObjectGUID
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

        Insert-Users -filteredUsers $filteredUsers 

        
    }
}