[CmdletBinding()]
param(
    [PSCredential] $Credential,
    [Parameter(Mandatory=$False, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId
)

# Replace the value of an appsettings of a given key in an XML App.Config file.
Function ReplaceSetting([string] $configFilePath, [string] $key, [string] $newValue)
{
    [xml] $content = Get-Content $configFilePath
    $appSettings = $content.configuration.appSettings; 
    $keyValuePair = $appSettings.SelectSingleNode("descendant::add[@key='$key']")
    if ($keyValuePair)
    {
        $keyValuePair.value = $newValue;
    }
    else
    {
        Throw "Key '$key' not found in file '$configFilePath'"
    }
   $content.save($configFilePath)
}


Function UpdateLine([string] $line, [string] $value, [bool] $dontUseDelimiter = $false )
{

    $index = $line.IndexOf(':')
    $delimiter = ','

    if ($index -eq -1)
    {
        $index = $line.IndexOf('=')
        $delimiter = ''
    }

    if ($dontUseDelimiter)
    {
        $delimiter = ''
    }

    if ($index -ige 0)
    {
        $line = $line.Substring(0, $index+1) + " "+'"'+$value+'"'+$delimiter
    }
    return $line
}

Function UpdateTextFile([string] $configFilePath, [System.Collections.HashTable] $dictionary)
{
    $lines = Get-Content $configFilePath
    $index = 0
    while($index -lt $lines.Length)
    {
        $line = $lines[$index]
        foreach($key in $dictionary.Keys)
        {
            
            if ($line.Contains($key))
            {
                # our application hack
                if ($line.Contains('URL'))
                {
                    $lines[$index] = UpdateLine $line $dictionary[$key] $true
                }
                else
                {
                    $lines[$index] = UpdateLine $line $dictionary[$key] $false
                }
            }
        }
        $index++
    }

    Set-Content -Path $configFilePath -Value $lines -Force
}


# Create a password that can be used as an application key
Function ComputePassword
{
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.GenerateKey()
    return [System.Convert]::ToBase64String($aesManaged.Key)
}

# Create an application key
# See https://www.sabin.io/blog/adding-an-azure-active-directory-application-and-key-using-powershell/
Function CreateAppKey([DateTime] $fromDate, [double] $durationInYears, [string]$pw)
{
    $endDate = $fromDate.AddYears($durationInYears) 
    $keyId = (New-Guid).ToString();
    $key = New-Object Microsoft.Open.AzureAD.Model.PasswordCredential
    $key.StartDate = $fromDate
    $key.EndDate = $endDate
    $key.Value = $pw
    $key.KeyId = $keyId
    return $key
}

# Adds the requiredAccesses (expressed as a pipe separated string) to the requiredAccess structure
# The exposed permissions are in the $exposedPermissions collection, and the type of permission (Scope | Role) is 
# described in $permissionType
Function AddResourcePermission($requiredAccess, `
                               $exposedPermissions, [string]$requiredAccesses, [string]$permissionType)
{
    foreach($permission in $requiredAccesses.Trim().Split("|"))
    {
        foreach($exposedPermission in $exposedPermissions)
        {
            if ($exposedPermission.Value -eq $permission)
                {
                $resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
                $resourceAccess.Type = $permissionType # Scope = Delegated permissions | Role = Application permissions
                $resourceAccess.Id = $exposedPermission.Id # Read directory data
                $requiredAccess.ResourceAccess.Add($resourceAccess)
                }
        }
    }
}


#
# Exemple: GetRequiredPermissions "Microsoft Graph"  "Graph.Read|User.Read"
# See also: http://stackoverflow.com/questions/42164581/how-to-configure-a-new-azure-ad-application-through-powershell
Function GetRequiredPermissions([string] $applicationDisplayName, [string] $requiredDelegatedPermissions, [string]$requiredApplicationPermissions, $servicePrincipal)
{
    # If we are passed the service principal we use it directly, otherwise we find it from the display name (which might not be unique)
    if ($servicePrincipal)
    {
        $sp = $servicePrincipal
    }
    else
    {
        $sp = Get-AzureADServicePrincipal -Filter "DisplayName eq '$applicationDisplayName'"
    }
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid 
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]

    # $sp.Oauth2Permissions | Select Id,AdminConsentDisplayName,Value: To see the list of all the Delegated permissions for the application:
    if ($requiredDelegatedPermissions)
    {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2Permissions -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
    }
    
    # $sp.AppRoles | Select Id,AdminConsentDisplayName,Value: To see the list of all the Application permissions for the application
    if ($requiredApplicationPermissions)
    {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}

<#
 This script creates the following artefacts in the Azure AD tenant.
 1) A number of App roles
 2) A set of users and assigns them to the app roles.

 Before running this script you need to install the AzureAD cmdlets as an administrator. 
 For this:
 1) Run Powershell as an administrator
 2) in the PowerShell window, type: Install-Module AzureAD

 There are four ways to run this script. For more information, read the AppCreationScripts.md file in the same folder as this script.
#>

# Create an application role of given name and description
Function CreateAppRole([string] $Name, [string] $Description)
{
    $appRole = New-Object Microsoft.Open.AzureAD.Model.AppRole
    $appRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
    $appRole.AllowedMemberTypes.Add("User");
    $appRole.DisplayName = $Name
    $appRole.Id = New-Guid
    $appRole.IsEnabled = $true
    $appRole.Description = $Description
    $appRole.Value = $Name;
    return $appRole
}

Function CreateUserRepresentingAppRole([string]$appName, $role, [string]$tenantName)
{
    $password = "test123456789."
    $displayName = $appName +"-" + $role.Value
    $userEmail = $displayName + "@" + $tenantName
    $nickName = $role.Value

    CreateUser -displayName $displayName -nickName $nickName -tenantName $tenantName
}

Function CreateUser([string]$displayName, [string]$nickName, [string]$tenantName)
{
    $password = "test123456789."
    $userEmail = $displayName + "@" + $tenantName
    $passwordProfile = New-Object Microsoft.Open.AzureAD.Model.PasswordProfile($password, $false, $false)

    New-AzureADUser -DisplayName $displayName -PasswordProfile $passwordProfile -AccountEnabled $true -MailNickName $nickName -UserPrincipalName $userEmail
}

Function CreateGroupsAndAddUser($user,$tenantName)
{
    CreateGroupAndAddUser -groupName $groupAdminName -user $user -firstUserName $userAdminUserName -tenantName $tenantName
    CreateGroupAndAddUser -groupName $groupResearcherName -user $user -firstUserName $userResearcherName -tenantName $tenantName
    CreateGroupAndAddUser -groupName $groupAnalystName -user $user -firstUserName $userAnalystName -tenantName $tenantName
    CreateGroupAndAddUser -groupName $groupBackgroundWorkerName -user $user -firstUserName $userBackgroundWorkerName -tenantName $tenantName
    CreateGroupAndAddUser -groupName $groupGuest -user $user -firstUserName $userGuestName -tenantName $tenantName
}


Function CreateGroupAndAddUser($groupName, $user, $firstUserName, $tenantName )
{
    $group = $null
    $groupExisting = Get-AzureADGroup -Filter "DisplayName eq '$groupName'" -ErrorAction Continue
    if (!$groupExisting)
    {
        $group = New-AzureADGroup -DisplayName $groupName -MailEnabled $False -SecurityEnabled $true -MailNickName $groupName

    }
    else
    {
        # interesting, the result returned could be more than one record for which we don't really cater for. 
        $group = $groupExisting
    }

    if ($group)
    {
        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId

        $password = "test123456789."
        $userEmail = $firstUserName + "@" + $tenantName
        $passwordProfile = New-Object Microsoft.Open.AzureAD.Model.PasswordProfile($password, $false, $false)

        $newUSer = New-AzureADUser -DisplayName $firstUserName -PasswordProfile $passwordProfile -AccountEnabled $true -MailNickName $firstUserName -UserPrincipalName $userEmail

        if ($newUser)
        {
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $newUSer.ObjectId
            # grant access to Key vault to the user
            Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ObjectId $newUSer.ObjectId -PermissionsToSecrets list,get
        }
        else
        {
            Write-Host "Failed to create user '($firstUserName)'"
        }
    }
    else
    {
        Write-Host "Failed to create group '($groupName)'"
    }
}

Function ApplyPermissions($appName, $permissions, $appObject)
{
   $r1 = GetRequiredPermissions -applicationDisplayName $appName -requiredDelegatedPermissions $permissions
   $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]
   $requiredResourcesAccess.Add($r1)
   Set-AzureADApplication -ObjectId $appObject.ObjectId -RequiredResourceAccess $requiredResourcesAccess
}

$global:serviceAppKey = $null
$global:webAppKey = $null 
#$serviceAppKey = $null
#$webAppKey = $null
$defaultServiceURL = "http://localhost:5555/"
$defaultWebAppURL = "https://localhost:5001/"
$defaultHTTPWebAppReplyURL = "http://localhost:5000/signin-oidc"


Function CreateAndConfigureService($user, $tenantName)
{
   # Create the service AAD application
   Write-Host "Creating the AAD application ($webServiceAppName))"
   # Get a 2 years application key for the service Application
   #$defaultURL = "https://localhost:5555/"
   $pw = ComputePassword
   $fromDate = [DateTime]::Now;
   $key = CreateAppKey -fromDate $fromDate -durationInYears 2 -pw $pw
   $global:serviceAppKey = $key
   $replayLogoutURL = $defaultServiceURL + "signout-oidc"
   $serviceAadApplication = New-AzureADApplication -DisplayName $webServiceAppName `
                                                   -HomePage $defaultServiceURL `
                                                   -AvailableToOtherTenants $false `
                                                   -LogoutUrl $replayLogoutURL `
                                                   -ReplyUrls "http://localhost:5555/" `
                                                   -PasswordCredentials $key `
                                                   -PublicClient $False
   $serviceIdentifierUri = 'api://'+$serviceAadApplication.AppId
   Set-AzureADApplication -ObjectId $serviceAadApplication.ObjectId -IdentifierUris $serviceIdentifierUri

   $currentAppId = $serviceAadApplication.AppId
   $serviceServicePrincipal = New-AzureADServicePrincipal -AppId $currentAppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}

   # add the user running the script as an app owner if needed
   $owner = Get-AzureADApplicationOwner -ObjectId $serviceAadApplication.ObjectId
   if ($owner -eq $null)
   { 
    Add-AzureADApplicationOwner -ObjectId $serviceAadApplication.ObjectId -RefObjectId $user.ObjectId
    Write-Host "'$($user.UserPrincipalName)' added as an application owner to app '$($serviceServicePrincipal.DisplayName)'"
   }

   Write-Host "Done creating the service application ('$webServiceAppName'))"

   # URL of the AAD application in the Azure portal
   # Future? $servicePortalUrl = "https://portal.azure.com/#@"+$tenantName+"/blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/appId/"+$serviceAadApplication.AppId+"/objectId/"+$serviceAadApplication.ObjectId+"/isMSAApp/"
   $servicePortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/"+$serviceAadApplication.AppId+"/objectId/"+$serviceAadApplication.ObjectId+"/isMSAApp/"
   Add-Content -Value "<tr><td>service</td><td>$currentAppId</td><td><a href='$servicePortalUrl'>$webServiceAppName</a></td></tr>" -Path createdApps.html

   $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]


   # Add Required Resources Access (from 'service' to 'Microsoft Graph')
   Write-Host "Getting access from 'service' to 'Microsoft Graph'"

   #ApplyPermissions -appName "Microsoft Graph" -permissions "Directory.Read.All" -appObject $serviceAadApplication
   #ApplyPermissions -appName "Azure Key Vault" -permissions "user_impersonation" -appObject $serviceAadApplication
   #ApplyPermissions -appName "Azure Storage" -permissions "user_impersonation" -appObject $serviceAadApplication
   #ApplyPermissions -appName "Microsoft.ServiceBus" -permissions "user_impersonation" -appObject $serviceAadApplication

   $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Microsoft Graph" -requiredDelegatedPermissions "User.Read" 
   $requiredResourcesAccess.Add($requiredPermissions)


   Write-Host "Getting access from 'service' to 'Azure Key Vault'"
   $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Azure Key Vault" -requiredDelegatedPermissions "user_impersonation" 
   $requiredResourcesAccess.Add($requiredPermissions)


   Write-Host "Getting access from 'service' to 'Azure Storage'"
   $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Azure Storage" -requiredDelegatedPermissions "user_impersonation" 
   $requiredResourcesAccess.Add($requiredPermissions)


   Write-Host "Getting access from 'service' to 'Microsoft.ServiceBus'"
   $requiredPermissions = GetRequiredPermissions -applicationDisplayName "Microsoft.ServiceBus" -requiredDelegatedPermissions "user_impersonation"
   $requiredResourcesAccess.Add($requiredPermissions)


   Set-AzureADApplication -ObjectId $serviceAadApplication.ObjectId -RequiredResourceAccess $requiredResourcesAccess
   Write-Host "Granted permissions to ($webServiceAppName)"

   return $serviceAadApplication
}



Function CreateAndConfigureFrontEndApp($user, $tenantName)
{
   # Create the webApp AAD application
   Write-Host "Creating the AAD application ('$WebAppName')"
   

   $pw = ComputePassword
   $fromDate = [DateTime]::Now;
   $key = CreateAppKey -fromDate $fromDate -durationInYears 2 -pw $pw
   $global:webAppKey = $key
   $replayLogoutURL = $defaultWebAppURL + "signout-oidc"
   $replybackURL = $defaultWebAppURL + "signin-oidc"
   $IdentifierUris = "https://" + $tenantName + $WebAppName



   $webAppAadApplication = New-AzureADApplication -DisplayName $WebAppName `
                                                  -HomePage $defaultWebAppURL `
                                                  -LogoutUrl $replayLogoutURL `
                                                  -ReplyUrls $defaultHTTPWebAppReplyURL, $replybackURL   `
                                                  -IdentifierUris $IdentifierUris `
                                                  -AvailableToOtherTenants $false `
                                                  -PasswordCredentials $webAppKey `
                                                  -Oauth2AllowImplicitFlow $false `
                                                  -PublicClient $False
                                                  

   $currentAppId = $webAppAadApplication.AppId
   $webAppServicePrincipal = New-AzureADServicePrincipal -AppId $currentAppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}

   # add the user running the script as an app owner if needed
   $owner = Get-AzureADApplicationOwner -ObjectId $webAppAadApplication.ObjectId
   if ($owner -eq $null)
   { 
    Add-AzureADApplicationOwner -ObjectId $webAppAadApplication.ObjectId -RefObjectId $user.ObjectId
    Write-Host "'$($user.UserPrincipalName)' added as an application owner to app '$($webAppServicePrincipal.DisplayName)'"
   }

   Write-Host "Done creating the webApp application (WebApp)"

   # URL of the AAD application in the Azure portal
   # Future? $webAppPortalUrl = "https://portal.azure.com/#@"+$tenantName+"/blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/appId/"+$webAppAadApplication.AppId+"/objectId/"+$webAppAadApplication.ObjectId+"/isMSAApp/"
   $webAppPortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/"+$webAppAadApplication.AppId+"/objectId/"+$webAppAadApplication.ObjectId+"/isMSAApp/"
   Add-Content -Value "<tr><td>webApp</td><td>$currentAppId</td><td><a href='$webAppPortalUrl'>WebApp-GroupClaims</a></td></tr>" -Path createdApps.html

   # Add Required Resources Access (from 'webApp' to 'Microsoft Graph')
   

   $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]

   #ApplyPermissions -appName "Microsoft Graph" -permissions "Directory.Read.All" -appObject $webAppAadApplication
   #ApplyPermissions -appName $webServiceAppName -permissions "user_impersonation" -appObject $webAppAadApplication
   Write-Host "Getting access from '$WebAppName' to 'Microsoft Graph'"
   #$r1 = GetRequiredPermissions -applicationDisplayName "Microsoft Graph" -requiredDelegatedPermissions "Directory.Read.All"
   # Above was possibly giving us Error AADSTS650056: Misconfigured application.
   $r1 = GetRequiredPermissions -applicationDisplayName "Microsoft Graph" -requiredDelegatedPermissions "User.Read"
   $requiredResourcesAccess.Add($r1)

   Write-Host "Getting access from '$WebAppName' to '$webServiceAppName'"
   $r2 = GetRequiredPermissions -applicationDisplayName $webServiceAppName -requiredDelegatedPermissions "user_impersonation"
   $requiredResourcesAccess.Add($r2)

   Write-Host "Getting access from '$WebAppName' to 'Microsoft.Azure.ActiveDirectory'"
   $r3 = GetRequiredPermissions -applicationDisplayName "Microsoft.Azure.ActiveDirectory" -requiredDelegatedPermissions "User.Read"
   $requiredResourcesAccess.Add($r3)
   
   Set-AzureADApplication -ObjectId $webAppAadApplication.ObjectId -RequiredResourceAccess $requiredResourcesAccess
   Write-Host "Granted permissions."

   return $webAppAadApplication

}

Set-Content -Value "<html><body><table>" -Path createdApps.html
Add-Content -Value "<thead><tr><th>Application</th><th>AppId</th><th>Url in the Azure portal</th></tr></thead><tbody>" -Path createdApps.html

Function CreateRolesUsersAndRoleAssignments(
    [PSCredential] $Credential,
    [Parameter(Mandatory=$False, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId
)
{
<#.Description
   This function creates the 
#> 

    # $tenantId is the Active Directory Tenant. This is a GUID which represents the "Directory ID" of the AzureAD tenant
    # into which you want to create the apps. Look it up in the Azure portal in the "Properties" of the Azure AD.

    # Login to Azure PowerShell (interactive if credentials are not already provided:
    # you'll need to sign-in with creds enabling your to create apps in the tenant)
    if (!$Credential -and $TenantId)
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
    $displayName = $creds.Account.Id
    $onlyName = $displayName.Substring(0,$displayName.IndexOf('@'))
    #$user = Get-AzureADUser -All $true |Where-Object {$_.userPrincipalName - "$onlyName"}
    $user = Get-AzureADUSer -Filter "startswith(UserPrincipalName, '$onlyName')"


    if ($user)
    {
        CreateGroupsAndAddUser -user $user -tenantName $tenantName
    }

    $serviceAadApplication = CreateAndConfigureService -user $user -tenantName $tenantName
    $webAppAadApplication = CreateAndConfigureFrontEndApp  -user $user -tenantName $tenantName


   # Configure known client applications for service 
   Write-Host "Configure known client applications for the 'service'"
   $knowApplications = New-Object System.Collections.Generic.List[System.String]
   $knowApplications.Add($webAppAadApplication.AppId)
   Set-AzureADApplication -ObjectId $serviceAadApplication.ObjectId -KnownClientApplications $knowApplications -ErrorAction Stop
   Write-Host "Configured Known Applications Scenario."


   # Update config file for 'webApp'
   #$configFile = $pwd.Path + "\..\appsettings.json"
   #Write-Host "Updating the sample code ($configFile)"
   #$dictionary = @{ "ClientId" = $webAppAadApplication.AppId;"TenantId" = $tenantId;"Domain" = $tenantName;"ClientSecret" = $webAppAppKey };
   #UpdateTextFile -configFilePath $configFile -dictionary $dictionary

   Add-Content -Value "</tbody></table></body></html>" -Path createdApps.html  


    # Add application Roles
    #$directoryViewerRole = CreateAppRole -Name "DirectoryViewers" -Description "Directory viewers can view objects in the whole directory."
    #$userreaderRole = CreateAppRole -Name "UserReaders"  -Description "User readers can read basic profiles of all users in the directory"

    #$appRoles = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.AppRole]
    #$appRoles.Add($directoryViewerRole)
    #$appRoles.Add($userreaderRole)
        
    # Add the roles
    #Write-Host "Adding app roles to to the app 'WebApp-RolesClaims' in tenant '$tenantName'"

    #$app=Get-AzureADApplication -Filter "DisplayName eq 'WebApp-RolesClaims'" 
    
    #if ($app)
    #{
    #    $servicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$($app.AppId)'"  
    #    
    #    Set-AzureADApplication -ObjectId $app.ObjectId -AppRoles $appRoles
    #    Write-Host "Successfully added app roles to the app 'WebApp-RolesClaims'."

     #   $appName = $app.DisplayName

     #   Write-Host "Creating users and assigning them to roles."

        # Create users
        # ------
        # Make sure that the user who is running this script is assigned to the Directory viewer role
        #Write-Host "Adding '$($user.DisplayName)' as a member of the '$($directoryViewerRole.DisplayName)' role"
        #$userAssignment = New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $servicePrincipal.ObjectId -Id $directoryViewerRole.Id

        # Creating a directory viewer
        ##Write-Host "Creating a user and assigning to '$($directoryViewerRole.DisplayName)' role"
        #$aDirectoryViewer = CreateUserRepresentingAppRole $appName $directoryViewerRole $tenantName
        #$userAssignment = New-AzureADUserAppRoleAssignment -ObjectId $aDirectoryViewer.ObjectId -PrincipalId $aDirectoryViewer.ObjectId -ResourceId $servicePrincipal.ObjectId -Id $directoryViewerRole.Id
        #Write-Host "Created "($anApprover.UserPrincipalName)" with password 'test123456789.'"

        # Creating a users reader
        #Write-Host "Creating a user and assigning to '$($userreaderRole.DisplayName)' role"
        #$auserreaderRole = CreateUserRepresentingAppRole $appName $userreaderRole $tenantName
        #$userAssignment = New-AzureADUserAppRoleAssignment -ObjectId $auserreaderRole.ObjectId -PrincipalId $auserreaderRole.ObjectId -ResourceId $servicePrincipal.ObjectId -Id $userreaderRole.Id
        #Write-Host "Created "($auserreaderRole.UserPrincipalName)" with password 'test123456789.'"
    #}
    #else {
    #    Write-Host "Failed to add app roles to the app 'WebApp-RolesClaims'."
    #}

   # Update config file for 'service'
   $configFile = $pwd.Path + "\FlaskWebAPI\appSecrets.py"
   Write-Host "Updating the sample code ($configFile)"
   $dictionary = @{ "DomainName" = $tenantName;"TenantId" = $tenantId;"ClientId" = $serviceAadApplication.AppId;"ClientSecret" = $global:serviceAppKey.Value };
   UpdateTextFile -configFilePath $configFile -dictionary $dictionary

   # Update config file for 'client'
   $configFile = $pwd.Path + "\MVCSecureApp\appsettings.json"
   Write-Host "Updating the sample code ($configFile)"

   $ServiceWebAPIURL = $defaultServiceURL + "todo/api/v1.0/tasks"

   $dictionary = @{ "Domain" = $tenantName;"TenantId" = $tenantId;"ClientId" = $webAppAadApplication.AppId;"ClientSecret" = $global:webAppKey.Value; "WebAPIResourceId" = $serviceAadApplication.AppId; "WebAPIURL" = $ServiceWebAPIURL; "URL" = $ServiceWebAPIURL  };
   UpdateTextFile -configFilePath $configFile -dictionary $dictionary


   #ReplaceSetting -configFilePath $configFile -key "ida:ClientId" -newValue $webAppAadApplication.AppId
   #ReplaceSetting -configFilePath $configFile -key "todo:TodoListScope" -newValue ("api://"+$serviceAadApplication.AppId+"/user_impersonation")
   #ReplaceSetting -configFilePath $configFile -key "todo:TodoListBaseAddress" -newValue $serviceAadApplication.HomePage
   Write-Host ""
   Write-Host "IMPORTANT: Please follow the instructions below to complete a few manual step(s) in the Azure portal":
   Write-Host "- For 'service'"
   Write-Host "  - Navigate to 'Service API'"
   Write-Host "  - Navigate to the Manifest page and change 'signInAudience' to 'AzureADandPersonalMicrosoftAccount'."
   Write-Host "  - [Optional] If you are a tenant admin, you can navigate to the API Permisions page and select 'Grant admin consent for (your tenant)'"
   Write-Host "- For 'client'"
   Write-Host "  - Navigate to 'Web API'"
   Write-Host "  - Navigate to the Manifest page and change 'signInAudience' to 'AzureADandPersonalMicrosoftAccount'."

    Write-Host -ForegroundColor Green "Run the ..\CleanupUsersAndRoles.ps1 command to remove users created for this sample's application ."
}

# Pre-requisites
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

CreateRolesUsersAndRoleAssignments -Credential $Credential -tenantId $globalTenantId
