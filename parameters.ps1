$RESOURCEGROUP_NAME="ninadkanthi.com"
$LOCATION="North Europe"
$globalTenantId="<<EnterYourTenantIDHERE>>"

$groupAdminName = "Admin_group"
$groupResearcherName = "Researcher_group"
$groupAnalystName = "Analyst_group"
$groupBackgroundWorkerName = "BackgroundWorker_group"
$groupGuest = "Guest_group"

$userAdminUserName = "Admin_User"
$userResearcherName = "Researcher_User"
$userAnalystName = "Analyst_User"
$userBackgroundWorkerName = "BackgroundWorker_User"
$userGuestName = "Guest_User"

$WebAppName = "Ninadk.FrontEndApp"
$webServiceAppName="Ninadk.PythonWebService"

$KeyVaultName ="ninadkdeveloperKeyVault"
$storageAccountName = "secureappstorage"
$KeyVault_StorageAccountKeyName="ninadkStorageAccountKey"

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


if ((Get-Module -ListAvailable -Name "AzureAD") -eq $null) { 
    Install-Module "AzureAD"  
} 


if ((Get-Module -ListAvailable -Name "Az.KeyVault") -eq $null) { 
    Install-Module "Az" -AllowClobber
}
 
Import-Module AzureAD
Import-Module Az.KeyVault


$ErrorActionPreference = 'Stop'





