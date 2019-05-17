# Pre-requisites
# Pre-requisites

. "$PSScriptRoot\parameters.ps1"

# sign in
Write-Host -ForegroundColor White "Logging in...";
Login-AzAccount;

# select subscription
Write-Host -ForegroundColor White "Selecting subscription '$SUBSCRIPTION'";
Select-AzSubscription -Tenant $SUBSCRIPTION_ID;


#Deliberately not clearing the resource group as our RG contains resources that were created by others

# Have we got the Secrets repository created in KeyVault
$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVault_StorageAccountKeyName -ErrorAction SilentlyContinue
if ($keyVaultSecret)
{
    Write-Host -ForegroundColor Yellow "Removing KeyVault secret '$KeyVault_StorageAccountKeyName', please confirm::"
    Remove-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVault_StorageAccountKeyName
}

# check if KeyVault exists and if not create it. 
$keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
if ($keyVault)
{
    Write-Host -ForegroundColor Yellow "Removing KeyVault '$KeyVaultName', please confirm::";
    Remove-AzKeyVault -VaultName $KeyVaultName
}

# Lets create the storage account now if it does not exist
$storageAccount = Get-AzStorageAccount -ResourceGroupName $RESOURCEGROUP_NAME -Name $storageAccountName -ErrorAction SilentlyContinue
if ($storageAccount)
{
    Write-Host -ForegroundColor Yellow "Removing storage '$storageAccountName', please confirm::";
    Remove-AzStorageAccount -ResourceGroupName $RESOURCEGROUP_NAME -Name $storageAccountName 
}

