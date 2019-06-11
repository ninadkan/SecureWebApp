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
        $groupMember = Get-AzureADGroupMember -ObjectId $group.ObjectId
        if (-not $groupMember)
        {
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId
        }
        else
        {
            Write-Host "group already exists '($groupMember)'"
        }

        $userEmail = $firstUserName + "@" + $tenantName

        $newUSer = Get-AzureADUSer -Filter "startswith(UserPrincipalName, '$userEmail')"
        if (-not $newUSer)
        {
         

            $password = "test123456789."
            
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
            Write-Host "user already exists '($userEmail)'"
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
$global:serviceIdentifierUri = $null
#$webAppKey = $null
$defaultServiceURL = "http://localhost:5555/"
$defaultWebAppURL = "https://localhost:5001/"
$defaultHTTPWebAppReplyURL = "http://localhost:5000/signin-oidc"


Function CreateAndConfigureService($user, $tenantName)
{
   # Create the service AAD application
   Write-Host "Creating the AAD application ($webServiceAppName))"

   $replayLogoutURL = $defaultServiceURL + "signout-oidc"

   $serviceAadApplication = Get-AzureADApplication -Filter "startswith(DisplayName, '$webServiceAppName')"

   if (-not $serviceAadApplication)
   {

       # Get a 2 years application key for the service Application
       #$defaultURL = "https://localhost:5555/"
       $pw = ComputePassword
       $fromDate = [DateTime]::Now;
       $key = CreateAppKey -fromDate $fromDate -durationInYears 2 -pw $pw
       $global:serviceAppKey = $key

       $serviceAadApplication = New-AzureADApplication -DisplayName $webServiceAppName `
                                                       -HomePage $defaultServiceURL `
                                                       -AvailableToOtherTenants $false `
                                                       -LogoutUrl $replayLogoutURL `
                                                       -ReplyUrls "http://localhost:5555/" `
                                                       -PasswordCredentials $key `
                                                       -PublicClient $False
       $global:serviceIdentifierUri = 'api://'+$serviceAadApplication.AppId
       Set-AzureADApplication -ObjectId $serviceAadApplication.ObjectId -IdentifierUris $global:serviceIdentifierUri

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
   }
   else
   {
        Write-Host "Application already exists '$webServiceAppName'"
   }

   return $serviceAadApplication
}



Function CreateAndConfigureFrontEndApp($user, $tenantName)
{
   # Create the webApp AAD application
   Write-Host "Creating the AAD application ('$WebAppName')"
   
   $replayLogoutURL = $defaultWebAppURL + "signout-oidc"
   $replybackURL = $defaultWebAppURL + "signin-oidc"
   $IdentifierUris = "https://" + $tenantName + $WebAppName

   $webAppAadApplication = Get-AzureADApplication -Filter "startswith(DisplayName, '$WebAppName')" 
   if (-not $webAppAadApplication)
   {
       $pw = ComputePassword
       $fromDate = [DateTime]::Now;
       $key = CreateAppKey -fromDate $fromDate -durationInYears 2 -pw $pw
       $global:webAppKey = $key

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
   }
   else
   {
        Write-Host "Application already exists '$WebAppName'"
   }

   return $webAppAadApplication

}

Set-Content -Value "<html><body><table>" -Path createdApps.html
Add-Content -Value "<thead><tr><th>Application</th><th>AppId</th><th>Url in the Azure portal</th></tr></thead><tbody>" -Path createdApps.html

Function CreateRolesUsersAndRoleAssignments(
    [Parameter(Mandatory=$True, HelpMessage='Credentials ID (This is a account credential to login to Azure subscription')]
    [PSCredential] $Credential,
    [Parameter(Mandatory=$True, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
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



   # Update config file for 'service'
   # Updating the global keys in case the applications were not created in this run, but were created previously. 

    if ($global:serviceIdentifierUri -eq $null)
    {
        Write-Host "Updating the global service URI variable"
        $global:serviceIdentifierUri = 'api://' + $serviceAadApplication.AppId
    }

    $dictionary = $null
    if ($global:serviceAppKey -eq $null)
    {
        #Write-Host "Updating the global service Key variable"
        #$SpId = Get-AzureADServicePrincipal -ObjectId $serviceAadApplication.AppId
        #$key = Get-AzureADServicePrincipalKeyCredential -ObjectId $SpId
        #$global:serviceAppKey = Get-AzureADApplicationKeyCredential  -ObjectId $SpId
        $dictionary = @{ "DomainName" = $tenantName;"TenantId" = $tenantId;"ClientId" = $serviceAadApplication.AppId;"serviceIdentifierUri" = $global:serviceIdentifierUri };
    }
    else
    {
        $dictionary = @{ "DomainName" = $tenantName;"TenantId" = $tenantId;"ClientId" = $serviceAadApplication.AppId;"ClientSecret" = $global:serviceAppKey.Value; "serviceIdentifierUri" = $global:serviceIdentifierUri };
    }
    $configFile = $pwd.Path + "\FlaskWebAPI\appSecrets.py"
    Write-Host "Updating the sample code ($configFile)"
    UpdateTextFile -configFilePath $configFile -dictionary $dictionary

    $dictionary = $null
    $ServiceWebAPIURL = $defaultServiceURL + "todo/api/v1.0/tasks"
    if ($global:webAppKey -eq $null)
    {
        #Write-Host "Updating the global web app  Key variable"
        #$global:webAppKey = Get-AzureADApplicationKeyCredential  -ObjectId $webAppAadApplication.AppId
        $dictionary = @{ "Domain" = $tenantName;"TenantId" = $tenantId;"ClientId" = $webAppAadApplication.AppId; "WebAPIResourceId" = $serviceAadApplication.AppId; "WebAPIURL" = $ServiceWebAPIURL; "URL" = $ServiceWebAPIURL  };
    }
    else
    {
        $dictionary = @{ "Domain" = $tenantName;"TenantId" = $tenantId;"ClientId" = $webAppAadApplication.AppId;"ClientSecret" = $global:webAppKey.Value; "WebAPIResourceId" = $serviceAadApplication.AppId; "WebAPIURL" = $ServiceWebAPIURL; "URL" = $ServiceWebAPIURL  };
    }
    # Update config file for 'web application'
    $configFile = $pwd.Path + "\MVCSecureApp\appsettings.json"
    Write-Host "Updating the sample code ($configFile)"
    UpdateTextFile -configFilePath $configFile -dictionary $dictionary

    # Update config file for 'Java Client'
    $dictionary = $null
    $configFile = $pwd.Path + "\MVCSecureApp\Views\Jscript\Index.cshtml"
    $authorityval = "https://login.microsoftonline.com/" + $tenantId
    $WebApiArrayScope = "[" + $global:serviceIdentifierUri + "/user_impersonation ]"
    $dictionary = @{ "authority:" = $authorityval;"clientID:" = $webAppAadApplication.AppId;"WebAPIURL:" = $ServiceWebAPIURL; "WebAPIScope:" = $WebApiArrayScope};
    UpdateTextFile -configFilePath $configFile -dictionary $dictionary
   
    #ReplaceSetting -configFilePath $configFile -key "ida:ClientId" -newValue $webAppAadApplication.AppId
    #ReplaceSetting -configFilePath $configFile -key "todo:TodoListScope" -newValue ("api://"+$serviceAadApplication.AppId+"/user_impersonation")
    #ReplaceSetting -configFilePath $configFile -key "todo:TodoListBaseAddress" -newValue $serviceAadApplication.HomePage
    Write-Host ""
    Write-Host "IMPORTANT: Please follow the instructions below to complete a few manual step(s) in the Azure portal":
    Write-Host "- For 'service'"
    Write-Host "  - Navigate to 'Service API'"
    Write-Host "  - Add Client Secret Manually if the service was created before - add reference to the appsecrets.py file'"
    Write-Host "- For 'client'"
    Write-Host "  - Navigate to 'Web App'"
    Write-Host "  - Add Client Secret Manually if the web app  was created before - add reference to the appconfig.json'"
  

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
#. "$PSScriptRoot\login.ps1"

#$passwd = ConvertTo-SecureString '<<EnterPasswordHere>>' -AsPlainText -Force
#$pscredential = New-Object System.Management.Automation.PSCredential('<<EnterUserNameHere>>', $passwd)
# CreateRolesUsersAndRoleAssignments -tenantId $globalTenantId

# Call the following once to clear cache 
# Disconnect-AzureAD
# Disconnect-AzAccount

CreateRolesUsersAndRoleAssignments
