# Pre-requisites
# Pre-requisites

. "$PSScriptRoot\parameters.ps1"
. "$PSScriptRoot\login.ps1"

# Call the following once to clear cache 
# Disconnect-AzureAD
# Disconnect-AzAccount

# sign in
Write-Host -ForegroundColor DarkYellow "Azure AD Logging in...";

$passwd = ConvertTo-SecureString '<<EnterYourPasswordHere>>' -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential('<<EnterYourUserNAMEHERE>>', $passwd)
$creds = Connect-AzureAD -Credential $pscredential -TenantId '<<EnterYourTenantIDHere>>' -AzureEnvironmentName AzureCloud



$displayName = $creds.Account.Id
$onlyName = $displayName.Substring(0,$displayName.IndexOf('@'))
$user = Get-AzureADUSer -Filter "startswith(UserPrincipalName, '$onlyName')"

if ($user)
{

    $OkToUpdateConfigFile = $false

    # check if KeyVault exists and if not create it. 
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    if (!$keyVault)
    {
        Write-Host -ForegroundColor Cyan "Creating new key vault service'$KeyVaultName'"
        $keyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $RESOURCEGROUP_NAME -Location $LOCATION
        if (!$keyVault)
        {
            Write-Host -ForegroundColor DarkRed "Error! creating Key Vault - Stop" 
        }
        else
        {
            # ensure that we can set access policies for ourselves
            Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ResourceGroupName $RESOURCEGROUP_NAME -ObjectId $user.ObjectId -PermissionsToKeys create,import,delete,list -PermissionsToSecrets get, list,set, delete, backup, restore, recover, purge   -PassThru
        }
    }

    if ($keyVault)
    {
        Write-Host -ForegroundColor Green "Using existing key vault '$KeyVaultName'"
            # Lets create the storage account now if it does not exist
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $RESOURCEGROUP_NAME -Name $storageAccountName -ErrorAction SilentlyContinue
        if (!$storageAccount)
        {
            # create the storage account
            Write-Host "Creating storage account '$storageAccountName'"
            $skuName = "Standard_LRS"
            $storageAccount = New-AzStorageAccount -ResourceGroupName $RESOURCEGROUP_NAME -Name $storageAccountName -Location $LOCATION -SkuName $skuName
        }

        # At this point, we have the storage account and the Key Vault. Brilliant
        if ($storageAccount)
        {
            # Have we got the Secrets repository created in KeyVault
            $keyVaultSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVault_StorageAccountKeyName -ErrorAction SilentlyContinue
            if (!$keyVaultSecret)
            {
                # it does not exist, lets create it
                $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $RESOURCEGROUP_NAME -Name $storageAccountName).Value[0]
                if ($storageAccountKey)
                {
                    #Store the key in the KeyVaultSecret
                    $secretValue = ConvertTo-SecureString $storageAccountKey -AsPlainText -Force
                    $secret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVault_StorageAccountKeyName -SecretValue $secretValue 
                    Write-Host -ForegroundColor DarkYellow "Remove this code later '$secret'"
                    $OkToUpdateConfigFile = $true
                }
                else
                {
                    Write-Host -ForegroundColor DarkRed "Unable to get Storage Account Key"
                }
            }
            else
            {
                # it already exists, assume that it contains the correct value and come out
                Write-Host -ForegroundColor DarkYellow "Key Vault Secret already exists"
                $secret = (Get-AzKeyVaultSecret -vaultName $KeyVaultName -name $KeyVault_StorageAccountKeyName).SecretValueText
                Write-Host -ForegroundColor Cyan "Remove this code later '$secret'"
                $OkToUpdateConfigFile = $true
            }
        }
        else
        {
            Write-Host -ForegroundColor DarkRed "Error! Unable to get the storage Account '$storageAccountName'"
        }
    }
    else
    {
        Write-Host -ForegroundColor DarkRed "Error! Unable to get the Key Vauly '$KeyVaultName'"
    }


    if ($OkToUpdateConfigFile)
    {   
        $configFile = $pwd.Path + "\FlaskWebAPI\appSecrets.py"
        Write-Host -ForegroundColor DarkYellow "Updating the sample code ($configFile)"
        $dictionary = @{ "KV_VAULT_URL" = $keyVault.VaultUri;"KV_Storage_AccountName" = $storageAccountName;"KV_Storage_AccountKeyName" = $KeyVault_StorageAccountKeyName;};
        UpdateTextFile -configFilePath $configFile -dictionary $dictionary
    }
}




