$global:domainName = "gcm.intra.groupama.fr"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptPath\base_insert\fill_groups.ps1"
Import-Module "$scriptPath\base_insert\fill_users.ps1"
Import-Module "$scriptPath\base_insert\fill_link_usr_grp.ps1"


#choosen domain change it if we need to take all the tree or other domain
$targetOuDn = "OU=DOSI,OU=GROUPES_NORMAUX,OU=GROUPES,OU=CENTRE-MANCHE,DC=gcm,DC=intra,DC=groupama,DC=fr"

#take all ad grp
$allAdGroups = Get-ADGroup -SearchBase $targetOuDn -Filter * -Server $global:domainName


Measure-Command {
    foreach ($group in $allAdGroups) {
        Write-Host "Traitement du groupe $($group.Name)..." -ForegroundColor Cyan

        #call insert group
        Insert-Groups -group $group

        #get all menber in a group
        $rawMembers = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive -Server $global:domainName
        $alreadySeen = @{}

        foreach ($member in $rawMembers) {
            if ($member.objectClass -eq 'user' -and -not $alreadySeen.ContainsKey($member.samAccountName)) {
                $user = [System.Linq.Enumerable]::FirstOrDefault(
                    $Users_GCM, 
                    [Func[object,bool]]{ param($x) $x.samAccountName -eq $member.samAccountName }
                )
                if ($user) {

                    #call insert user
                    Insert-User -user $user 

                    #call insert in table link user group
                    Insert-link-User-Group -id_group $group.ObjectGUID -id_user $user.ObjectGUID

                    $alreadySeen[$member.samAccountName] = $true
                }
            }
        }

        

        
    }
}