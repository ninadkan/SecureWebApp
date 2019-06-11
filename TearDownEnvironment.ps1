Import-Module AzureAD
$ErrorActionPreference = 'Stop'


Function RemoveUser([string]$userPrincipal)
{
    $user = Get-AzureADUser -Filter "UserPrincipalName eq '$userPrincipal'"
    if ($user)
    {
        Write-Host "Removing User '($userPrincipal)'"
        # Remove the access to the KeyVault as well
        Remove-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ObjectId $user.ObjectId
        # Remove the user now. 
        Remove-AzureADUser -ObjectId $user.ObjectId
    }
    else {
        Write-Host "Failed to remove user '($userPrincipal)'"
    }
}

Function RemoveUsersFromGroup($groupName, $userId, $firstUserDisplayName)
{
    $group = Get-AzureADGroup -Filter "DisplayName eq '$groupName'" -ErrorAction Continue
    if ($group)
    {
        # we are not going to remove the $userId as its the core. 
        Remove-AzureADGroupMember -ObjectId $group.ObjectId -MemberId $userId.ObjectId -ErrorAction Continue

        #Assuming that we get our user with unique diplay name. This might not be valid for everything. 
        $userFound = Get-AzureADUser -Filter "DisplayName eq '$firstUserDisplayName'"
        if ($userFound)
        {
            Remove-AzureADGroupMember -ObjectId $group.ObjectId -MemberId $userFound.ObjectId -ErrorAction Continue
            # now delete the user as well 
            Remove-AzureADUser -ObjectId $userFound.ObjectId -ErrorAction Continue
        }
    }
    else
    {
        Write-Host "Failed to find group '($groupName)'"
    }
}


Function RemoveGroup($groupName)
{
    $group = Get-AzureADGroup -Filter "DisplayName eq '$groupName'" -ErrorAction Continue
    if ($group)
    {
        Remove-AzureADGroup -ObjectId $group.ObjectId -ErrorAction Continue
    }
    else
    {
        Write-Host "Failed to find group '($groupName)'"
    }
}


Function CleanupUsers (    [PSCredential] $Credential,
    [Parameter(Mandatory=$False, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId)
{
    <#
    .Description
    This function removes the users created in the Azure AD tenant by the CreateUsersAndRoles.ps1 script.
    #>

    # $tenantId is the Active Directory Tenant. This is a GUID which represents the "Directory ID" of the AzureAD tenant 
    # into which you want to create the apps. Look it up in the Azure portal in the "Properties" of the Azure AD. 

    # Login to Azure PowerShell (interactive if credentials are not already provided:
    # you'll need to sign-in with creds enabling your to create apps in the tenant)
    if (!$Credential -and $tenantId)
    {
        $creds = Connect-AzureAD -TenantId $tenantId
    }
    else
    {
        if (!$tenantId)
        {
            $creds = Connect-AzureAD -Credential $Credential
        }
        else
        {
            $creds = Connect-AzureAD -TenantId $tenantId -Credential $Credential
        }
    }

    if (!$tenantId)
    {
        $tenantId = $creds.Tenant.Id
    }

    $tenant = Get-AzureADTenantDetail
    $tenantName =  ($tenant.VerifiedDomains | Where { $_._Default -eq $True }).Name

    # Get the user running the script
    # Following does not work!!!
    # $user = Get-AzureADUser -ObjectId $creds.Account.Id
    #$displayName = $creds.Account.Id
    #$userFound = $AllUsers |Where-Object {$_.DisplayName -like "$displayName*"}

    # Get the user running the script
    # Following does not work!!!
    # $user = Get-AzureADUser -ObjectId $creds.Account.Id
    $displayName = $creds.Account.Id
    $onlyName = $displayName.Substring(0,$displayName.IndexOf('@'))
    #$user = Get-AzureADUser -All $true |Where-Object {$_.userPrincipalName - "$onlyName"}
    $user = Get-AzureADUSer -Filter "startswith(UserPrincipalName, '$onlyName')"


    if ($user)
    {
        RemoveUsersFromGroup -groupName $groupResearcherName -userId $user -firstUserDisplayName $userResearcherName
        RemoveUsersFromGroup -groupName $groupAnalystName -userId $user -firstUserDisplayName $userAnalystName
        RemoveUsersFromGroup -groupName $groupBackgroundWorkerName -userId $user -firstUserDisplayName $userBackgroundWorkerName
        RemoveUsersFromGroup -groupName $groupGuest -userId $user -firstUserDisplayName $userGuestName
        RemoveUsersFromGroup -groupName $groupAdminName -userId $user -firstUserDisplayName $userAdminUserName

        RemoveGroup -groupName $groupGuest 
        RemoveGroup -groupName $groupBackgroundWorkerName 
        RemoveGroup -groupName $groupAnalystName
        RemoveGroup -groupName $groupResearcherName 
        RemoveGroup -groupName $groupAdminName 
    }

    



    #$appName = "WebApp-RolesClaims"

    # Removes the users created for the application
    #Write-Host "Removing Users"
    #RemoveUser -userPrincipal "$appName-DirectoryViewers@$tenantName"
    #RemoveUser -userPrincipal "$appName-UserReaders@$tenantName"


    Write-Host "Cleaning-up applications from tenant '$tenantName'"


     Write-Host "Removing 'service' $webServiceAppName if needed"
    $app=Get-AzureADApplication -Filter "DisplayName eq '$webServiceAppName'"  -ErrorAction Continue

    if ($app)
    {
        Remove-AzureADApplication -ObjectId $app.ObjectId
        Write-Host "Removed $webServiceAppName"
    }

    Write-Host "Removing 'app' ('$WebAppName') if needed"
    $app=Get-AzureADApplication -Filter "DisplayName eq '$WebAppName'" -ErrorAction Continue

    if ($app)
    {
        Remove-AzureADApplication -ObjectId $app.ObjectId
        Write-Host "Removed. $WebAppName"
    }

    Write-Host "finished removing  users and groups created for this app." 
}

# Pre-requisites
if ((Get-Module -ListAvailable -Name "AzureAD") -eq $null) { 
    Install-Module "AzureAD" 
} 


if ((Get-Module -ListAvailable -Name "Az.KeyVault") -eq $null) { 
    Install-Module "Az" -AllowClobber
}
 
Import-Module AzureAD
Import-Module Az.KeyVault

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\parameters.ps1"


#CleanupUsers -Credential $Credential -tenantId $globalTenantId

# Call the following once to clear cache 
# Disconnect-AzureAD
# Disconnect-AzAccount

CleanupUsers
