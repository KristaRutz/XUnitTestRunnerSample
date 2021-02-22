Import-Module $PSScriptRoot\Microsoft.Azure.Monitoring.WarmPath.Client.dll -Global
Import-Module $PSScriptRoot\Microsoft.Azure.Monitoring.WarmPath.Cmdlets.dll -Global
Import-Module $PSScriptRoot\Microsoft.Azure.Monitoring.WarmPath.Contracts.Common.dll -Global
Import-Module $PSScriptRoot\Microsoft.Azure.Monitoring.WarmPath.Contracts.WarmPathResources.dll -Global
[System.AppContext]::SetSwitch("Switch.System.IdentityModel.DisableCngCertificates", $false)

# Handle binding redirects.
$scriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$systemWebHttpPath = [System.IO.Path]::Combine($scriptPath, "System.Web.Http.dll")

if (!("Redirector" -as [type]))
{
$source = 
@'
	using System;
	using System.Collections.Generic;
	using System.IO;
	using System.Reflection;

        public static class Redirector
        {
            private static Dictionary<string, string> _assemblies;

            static Redirector()
            {
                var comparer = StringComparer.CurrentCultureIgnoreCase;
                _assemblies = new Dictionary<string, string>(comparer);
                AppDomain.CurrentDomain.AssemblyResolve += ResolveHandler;
            }

            public static void AddAssemblyLocation(string path)
            {
                string name = Path.GetFileNameWithoutExtension(path);
                _assemblies[name] = path;
            }

            private static Assembly ResolveHandler(object sender, ResolveEventArgs args) 
            {
                var assemblyName = new AssemblyName(args.Name);
                if (_assemblies.ContainsKey(assemblyName.Name))
                {
                    var path = _assemblies[assemblyName.Name];
					
                    return Assembly.LoadFrom(path);
                }

                return null;
            }
        }
'@

    $type = Add-Type -TypeDefinition $source -PassThru 
}

# Add binding redirects
[Redirector]::AddAssemblyLocation($systemWebHttpPath)

<#
.SYNOPSIS
Creates a new Warm Path account
.EXAMPLE
CreateWarmPathAccount -environment 'Test' -accountName 'MyAccountName' -email 'MyAdminEmail@microsoft.com' -isGsmEnabled $true [-isGcsEnabled $true] [-adminSecurityGroup 'Redmond\MySg'] [-adminUserAliases 'MyAlias','OthersAlias']
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
.PARAMETER email
The distribution email associated with the account.
.PARAMETER isGsmEnabled
Is GSM enabled for the account.
.PARAMETER isGcsEnabled
Is GCS enabled for the account. Default is true.
.PARAMETER adminSecurityGroup
The admin security group. Must specify adminSecurityGroup and/or 2 adminUserAliases.
.PARAMETER adminUserAliases
The admin user aliases. Must specify adminSecurityGroup and/or 2 adminUserAliases.
#>
function CreateWarmPathAccount 
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName,
        [Parameter(Mandatory=$true)][string] $email,
        [Parameter(Mandatory=$true)][bool] $isGsmEnabled = $true,
        [Parameter(Mandatory=$false)][bool] $isGcsEnabled = $true,
        [Parameter(Mandatory=$false)][string] $adminSecurityGroup = $null,
        [Parameter(Mandatory=$false)][string[]] $adminUserAliases = $null)
    process {
        $account = $null
        $accountExists = $true

        # Check for existing user role
        try
        {
            $account = Get-WarmPathAccount -WarmPathEnvironment $environment -WarmPathAccountName $accountName
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            if ($_.Exception.Error.Code -ne "Forbidden" -and $_.Exception.Error.Code -ne "NotFound")
            {
                Write-Host "Failed to get Account with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
                throw
            }

            $accountExists = $false

			$accountParams = @{
				AccountName = $accountName
				Email = $email
				IsGcsEnabled = $isGcsEnabled
				IsGsmEnabled = $isGsmEnabled
			}
			if ($adminSecurityGroup -ne $null)
            {
				$accountParams += @{AdminSecurityGroup = $adminSecurityGroup}
            }
            if ($adminUserAliases -ne $null)
            {
				$accountParams += @{AdminUserAliases = $adminUserAliases}
            }

			$account = New-WarmPathAccountObject @accountParams 
        }

        try
        {
            if ($accountExists)
            {
                if ($account.Email -ne $email -or $account.AdminSecurityGroup -ne $adminSecurityGroup)
                {
					$error = New-WarmPathError -Message "Account $($accountName) already exists" -Code "Conflict"
					$exception = New-WarmPathException -Error $error
                    throw $exception
                }
            }
            else
            {
                $account = New-WarmPathAccount -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $account
            }

            Write-Host "Created account '$accountName' in environment '$environment'."
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to create account with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

<#
.SYNOPSIS
Creates a new namespace under a Warm Path account
.EXAMPLE
CreateWarmPathNamespace -environment 'Test' -accountName 'MyAccountName' -namespace 'MyNamespace'  [-serviceTreeGuid '00000000-0000-0000-0000-000000000000']
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
.PARAMETER namespace
The namespace to add.
.PARAMETER serviceTreeGuid
The service tree guid to associate with the namespace.
#>
function CreateWarmPathNamespace
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName,
        [Parameter(Mandatory=$true)][string] $namespace,
        [Parameter(Mandatory=$false)][string] $serviceTreeGuid = $null)
    process {
        try
        {
            if ([System.string]::IsNullOrEmpty($serviceTreeGuid))
            {
                $success = New-WarmPathNamespace -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Namespace $namespace
            }
            else
            {
                $success = New-WarmPathNamespace -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Namespace $namespace -ServiceTreeGuid $serviceTreeGuid
            }

            Write-Host "Added namespace '$namespace' to account '$accountName'."
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to add namespace '$namespace' with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

<#
.SYNOPSIS
Creates a new user role under a Warm Path account
.EXAMPLE
CreateWarmPathUserRole -environment 'Test' -accountName 'MyAccountName' -userRoleId "$($namespace)_RO" [-securityGroup 'Redmond\MySg'] [-certThumbprint 'CERT_THUMBPRINT' -certIssuer 'CERT_ISSUER'] [-isReadOnly $true] [-isMaCommunication $false]
.EXAMPLE
CreateWarmPathUserRole -environment 'Test' -accountName 'MyAccountName' -userRoleId "$($namespace)_RW" [-securityGroup 'Redmond\MySg'] [-certThumbprint 'CERT_THUMBPRINT' -certIssuer 'CERT_ISSUER'] [-isReadOnly $false] [-isMaCommunication $false]
.EXAMPLE
CreateWarmPathUserRole -environment 'Test' -accountName 'MyAccountName' -userRoleId "$($namespace)_MaCommunication" [-securityGroup $null] [-certThumbprint 'CERT_THUMBPRINT' -certIssuer 'CERT_ISSUER'] [-isReadOnly $false] [-isMaCommunication $true]
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
.PARAMETER userRoleId
The user role id.
.PARAMETER namespace
The namespace
.PARAMETER securityGroup
The security group.
.PARAMETER certThumbprint
The certificate thumbprint.
.PARAMETER certIssuer
The certificate issuer.
.PARAMETER isReadOnly
Is this a read only user role. Default is true.
.PARAMETER isMaCommunication
Is this an MaCommunication user role. Default is false.
#>
function CreateWarmPathUserRole
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName,
        [Parameter(Mandatory=$true)][string] $userRoleId,
        [Parameter(Mandatory=$true)][string] $namespace,
        [Parameter(Mandatory=$false)][string] $securityGroup = $null,
        [Parameter(Mandatory= $false)][string] $certThumbprint = $null,
        [Parameter(Mandatory= $false)][string] $certIssuer = $null,
        [Parameter(Mandatory=$false)][bool] $isReadOnly = $true,
        [Parameter(Mandatory=$false)][bool] $isMaCommunication = $false)
    process {
        $config = $null
        $userRoleExists = $true

        # Check for existing user role
        try
        {
            $config = Get-WarmPathUserRole -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Id $userRoleId
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            if ($_.Exception.Error.Code -ne "NotFound")
            {
                Write-Host "Failed to get UserRole with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
                throw
            }

            $userRoleExists = $false
			$config = New-UserRoleConfigurationObject -Id $userRoleId

            if ($isMaCommunication -eq $false)
            {
                # Add read account claim to both roles
				$readAccountClaim = New-WarmPathClaim -ClaimKind "AccountAdmin" -ClaimPermission "Read" -ClaimResource $accountName
        
                $success = $config.Claims.Add($readAccountClaim)
            }
        }

        if ($isMaCommunication)
        {
            # Add Agent claim
            $agentClaim = New-WarmPathClaim -ClaimKind "Agent" -ClaimPermission "Execute" -ClaimResource $("^" + $namespace + ".*")
        
            $success = $config.Claims.Add($agentClaim)
        }
        else
        {
            # Add Read claim
            $readClaim = New-WarmPathClaim -ClaimKind "Config" -ClaimPermission "Read" -ClaimResource $("^" + $namespace + ".*")
        
            $success = $config.Claims.Add($readClaim)

            # Add Write claim if applicable
            if ($isReadOnly -eq $false)
            {
                $writeClaim = New-WarmPathClaim -ClaimKind "Config" -ClaimPermission "Write" -ClaimResource $("^" + $namespace + ".*")
        
                $success = $config.Claims.Add($writeClaim)
            }
        }

        # Add security group
        if ([System.string]::IsNullOrEmpty($securityGroup) -eq $false)
        {
            if ($isMaCommunication)
            {
				Write-Host "Cannot specify security group for MaCommunication role" -ForegroundColor Red
				throw
            }

            $sg = New-WarmPathSecurityGroup -Name $securityGroup
            $success = $config.SecurityGroups.Add($sg)
        }

        # Add certificate
        if ([System.string]::IsNullOrEmpty($certThumbprint) -eq $false)
        {
            if ([System.string]::IsNullOrEmpty($certIssuer))
            {
				Write-Host "Must specify issuer if thumbprint is specified" -ForegroundColor Red
				throw
            }

            $cert = New-WarmPathCertificate -Thumbprint $certThumbprint -Issuer $certIssuer
			$success = $config.Certificates.Add($cert)
        }

        # Add or update user role
        try
        {
            if ($userRoleExists)
            {
                $config = Set-WarmPathUserRole -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Id $userRoleId -Configuration $config
            }
            else
            {
                $config = New-WarmPathUserRole -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $config
            }

            Write-Host "Added namespace '$namespace' to $(If ($isReadOnly) {"read only"} Else {"read write"}) user role '$($config.Id)'."
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to update UserRole with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

<#
.SYNOPSIS
Creates a new moniker under a Warm Path account
.EXAMPLE
CreateWarmPathMoniker -environment 'Test' -accountName 'MyAccountName' -region 'westus' -moniker 'MyMoniker' -subscriptionId 'subId' -resourceGroup 'RG' -storageAccountName 'myStorageAccountName' -storageKey 'ENCRYPTED_OR_UNENCRYPTED_KEY' [-eventHubAccountName 'myEventHubAccountName -eventHubConnectionString 'ENCRYPTED_OR_UNENCRYPTED_STRING'] [-encrypt $true]
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
.PARAMETER region
The region.
.PARAMETER moniker
The moniker.
.PARAMETER subscriptionId
The azure subscription id.
.PARAMETER resourceGroup
The azure resource group.
.PARAMETER storageAccountName
The storage account name.
.PARAMETER storageKey
The storage key.
.PARAMETER eventHubAccountName
The event hub account name.
.PARAMETER eventHubConnectionString
The encrypted or unencrypted connection string.
.PARAMETER encrypt
Is encryption of the storage key and event hub connection string required. Default is true.
#>
function CreateWarmPathMoniker
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName,
        [Parameter(Mandatory=$true)][string] $region,
        [Parameter(Mandatory=$true)][string] $moniker,
        [Parameter(Mandatory=$false)][string] $subscriptionId,
        [Parameter(Mandatory=$false)][string] $resourceGroup,
        [Parameter(Mandatory=$true)][string] $storageAccountName,
        [Parameter(Mandatory=$true)][string] $storageKey,
        [Parameter(Mandatory=$false)][string] $eventHubAccountName,
        [Parameter(Mandatory=$false)][string] $eventHubConnectionString,
        [Parameter(Mandatory=$false)][bool] $encrypt = $true)
    process {
        $config = $null
        $configExists = $true

        # Check for existing moniker
        try
        {
            $config = Get-WarmPathMoniker -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Moniker $moniker
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            if ($_.Exception.Error.Code -ne "NotFound")
            {
                Write-Host "Failed to get UserRole with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
                throw
            }

            $configExists = $false
        }

        try
        {
            $storageSuffix = "core.windows.net"

            if ($environment -like "CaMooncake")
            {
                $storageSuffix = "core.chinacloudapi.cn"
            }
            elseif ($environment -like "CaFairfax")
            {
                $storageSuffix = "core.usgovcloudapi.net"
            }
            elseif ($environment -like "CaBlackforest")
            {
                $storageSuffix = "core.cloudapi.de"
            }
			elseif ($environment -like "UsSec")
            {
                $storageSuffix = "core.microsoft.scloud"
            }
            elseif ($environment -like "UsNat")
            {
                $storageSuffix = "core.eaglex.ic.gov"
            }

            # create storage account object
            if ($encrypt)
            {
                $storageKey = Get-WarmPathEncryptedText -WarmPathEnvironment $environment -WarmPathAccountName $accountName -PlainText $storageKey
            }

            $storageAccountObject = New-WarmPathStorageAccountObject -SubscriptionId $subscriptionId -ResourceGroup $resourceGroup -StorageNamespace $storageAccountName -EncryptedKey $storageKey -BlobUri "https://blob.$($storageSuffix)" -QueueUri "https://queue.$($storageSuffix)" -TableUri "https://table.$($storageSuffix)"

            # create updated object
            if ([System.string]::IsNullOrEmpty($eventHubAccountName))
            {
                $config = New-WarmPathMonikerObject -Moniker $moniker -Region $region -StorageAccount $storageAccountObject 
            }
            else
            {
                if ($encrypt)
                {
                    $eventHubConnectionString = Get-WarmPathEncryptedText -WarmPathEnvironment $environment -WarmPathAccountName $accountName -PlainText $eventHubConnectionString
                }

                $eventHubAccountObject = New-WarmPathEventHubAccountObject -EventHubNamespace $eventHubAccountName -EncryptedConnectionString $eventHubConnectionString       
                $config = New-WarmPathMonikerObject -Moniker $moniker -Region $region -StorageAccount $storageAccountObject -EventHubAccount $eventHubAccountObject
            }

            # persist changes
            if ($configExists)
            {            
                $config = Set-WarmPathMoniker -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $config -Moniker $moniker
            }
            else
            {
                $config = New-WarmPathMoniker -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $config
            }

            Write-Host "Created new moniker. Moniker:$($config.Moniker)"
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to add moniker with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

<#
.SYNOPSIS
Creates a new monitoring configuration under a Warm Path account
.EXAMPLE
CreateWarmPathMonitoringConfiguration -environment 'Test' -accountName 'MyAccountName' -configNamespace 'MyConfigNamespace' -majorVersion 1 -mainConfigFilePath '.\MyConfigNamespaceVer1v0\MyConfigNamespaceVer1v0.xml' -importConfigFileDirectory '.\MyConfigNamespaceVer1v0\Imports' [-isDeployed $true]
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
.PARAMETER configNamespace
The config namespace.
.PARAMETER majorVersion
The major version.
.PARAMETER mainConfigFilePath
The path of the main config file.
.PARAMETER importConfigFileDirectory
The directory containing only the import config files.
.PARAMETER isDeployed
Is this config in deployed state. Default is true.
#>
function CreateWarmPathMonitoringConfiguration
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName,
        [Parameter(Mandatory=$true)][string] $configNamespace,
        [Parameter(Mandatory=$true)][int] $majorVersion,
        [Parameter(Mandatory=$true)][string] $mainConfigFilePath,
        [Parameter(Mandatory=$true)][string] $importConfigFileDirectory,
        [Parameter(Mandatory=$false)][bool] $isDeployed = $true)
    process {
        $config = $null
        $configExists = $true

        # Check for existing config
        try
        {
            $config = Get-WarmPathMonitoringConfiguration -WarmPathEnvironment $environment -WarmPathAccountName $accountName -ConfigNamespace $configNamespace -MajorVersion $majorVersion
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            if ($_.Exception.Error.Code -ne "NotFound")
            {
                Write-Host "Failed to get UserRole with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
                throw
            }

            $configExists = $false
        }

        try
        {
            $configObject = Read-WarmPathMonitoringConfigurationFromDisk -ConfigNamespace $configNamespace -MajorVersion $majorVersion -MainConfigFilePath $mainConfigFilePath -ImportConfigFilesDirectory $importConfigFileDirectory
            $configObject.IsDeployed = $isDeployed

            if ($configExists)
            {
                $config = Set-WarmPathMonitoringConfiguration -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $configObject -ConfigNamespace $configNamespace -MajorVersion $majorVersion
            }
            else
            {
                $config = New-WarmPathMonitoringConfiguration -WarmPathEnvironment $environment -WarmPathAccountName $accountName -Configuration $configObject
            }

            Write-Host "Created new configuration. ConfigNamespace:$($config.ConfigNamespace), MajorVersion:$($config.MajorVersion), MinorVersion:$($config.MinorVersion)"
        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to add configuration with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

<#
.SYNOPSIS
Gets a summary of resources in a Warm Path account. Only retrieves cached resources.
.EXAMPLE
GetWarmPathAccountSummary -environment 'Test' -accountName 'MyAccountName'
.PARAMETER environment
The Warm Path environment to use. (Smoke|Test|Stage|DiagnosticsProd|FirstpartyProd|BillingProd|ExternalProd|CaMooncake|CaFairfax|CaBlackforest)
.PARAMETER accountName
The Warm Path account name.
#>
function GetWarmPathAccountSummary
{
    param(
        [Parameter(Mandatory=$true)][string] $environment, 
        [Parameter(Mandatory=$true)][string] $accountName)
    process {
        try
        {
            $account = Get-WarmPathAccount -WarmPathEnvironment $environment -WarmPathAccountName $accountName
            $userRoles = Get-WarmPathUserRole -WarmPathEnvironment $environment -WarmPathAccountName $accountName
            $monikers = Get-WarmPathMoniker -WarmPathEnvironment $environment -WarmPathAccountName $accountName
            $configs = Get-WarmPathMonitoringConfiguration -WarmPathEnvironment $environment -WarmPathAccountName $accountName

            # Acount
            Write-Host "AccountName:$($account.AccountName)"
            Write-Host "AdminSecurityGroup:$($account.AdminSecurityGroup)"
            Write-Host "Email:$($account.Email)"
            Write-Host "MdmAccountName:$($account.MdmAccountName)"
            Write-Host "IsGcsEnabled:$($account.IsGcsEnabled)"
            Write-Host "AdminUserAliases:$($account.AdminUserAliases -join ',')"

            # UserRoles
            Write-Host "`nUserRoles:$($userRoles.Count)"
            
            $userRoles | ForEach-Object { Write-Host "Id:$($_.Id),ClaimsCount:$($_.Claims.Count),CertCount:$($_.Certificates.Count),SecurityGroupCount:$($_.SecurityGroups.Count),UsersCount:$($_.Users.Count)" }


            Write-Host "`nMonikers:$($configs.Count)"

            $monikers | ForEach-Object { Write-Host "Moniker:$($_.Moniker),StorageAccount:$($_.StorageAccount.StorageAccountName),EventHubAccount:$($_.EventHubAccount.EventHubNamespace),EventHubPublisher:$($_.EventHubPublisher.EventHubNamespace)" }

            Write-Host "`nMonitoringConfigurations:$($configs.Count)"

            $configs | ForEach-Object { Write-Host "ConfigNamespace:$($_.ConfigNamespace),MajorVersion:$($_.MajorVersion),MinorVersion:$($_.MinorVersion),IsDeployed:$($_.IsDeployed)" }

        }
        catch [Microsoft.Azure.Monitoring.WarmPath.Cmdlets.WarmPathException]
        {
            Write-Host "Failed to add configuration with exception: $($_.Exception.Error.Message)" -ForegroundColor Red
            throw
        }
    }
}

# SIG # Begin signature block
# MIInPAYJKoZIhvcNAQcCoIInLTCCJykCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAA6BmTzGMd/tIq
# d4t4l9P7+HTC3ubYX07HkKJkA536JKCCEWkwggh7MIIHY6ADAgECAhM2AAABOgNw
# leIA4C4dAAEAAAE6MA0GCSqGSIb3DQEBCwUAMEExEzARBgoJkiaJk/IsZAEZFgNH
# QkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxFTATBgNVBAMTDEFNRSBDUyBDQSAwMTAe
# Fw0yMDEwMjEyMDM5NTJaFw0yMTA5MTUyMTQzMDNaMCQxIjAgBgNVBAMTGU1pY3Jv
# c29mdCBBenVyZSBDb2RlIFNpZ24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDDDS+b5DVWKtu8bpHxdAFKwLne5h8oB2TtG76NrpMklR5ovQ5DT+ZqzusC
# tVzXyNUPzMmoUn3Re5uCuIUXhxXwxdzmF0sm6xA+EuAt4RnI1ISULXFu17dftwEB
# noLnqssMBMPMosP8mILFrzWc8H/Vv5ZWRg6FUlgDVGLPI7oMGzqv5HluTJ4tNiFL
# DDyX7VhOVqN9o3DcBu5Vsyb7pKhPtEetiXw8zH91J2dbXoSgFm3+ZsMg2xGMVc4L
# vMulYjDB09T3wEwJE/UQbnX5rmdASK6OVK6YzjyMwdhDePuPc9BRHufvv4CSwXgW
# uPcLW+1741qdqc2B0bbFjCn/7Kb9AgMBAAGjggWHMIIFgzApBgkrBgEEAYI3FQoE
# HDAaMAwGCisGAQQBgjdbAQEwCgYIKwYBBQUHAwMwPQYJKwYBBAGCNxUHBDAwLgYm
# KwYBBAGCNxUIhpDjDYTVtHiE8Ys+hZvdFs6dEoFgg93NZoaUjDICAWQCAQwwggJ2
# BggrBgEFBQcBAQSCAmgwggJkMGIGCCsGAQUFBzAChlZodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpaW5mcmEvQ2VydHMvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDEu
# YW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUy
# MDAxKDEpLmNydDBSBggrBgEFBQcwAoZGaHR0cDovL2NybDIuYW1lLmdibC9haWEv
# QlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBS
# BggrBgEFBQcwAoZGaHR0cDovL2NybDMuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAx
# LkFNRS5HQkxfQU1FJTIwQ1MlMjBDQSUyMDAxKDEpLmNydDBSBggrBgEFBQcwAoZG
# aHR0cDovL2NybDQuYW1lLmdibC9haWEvQlkyUEtJQ1NDQTAxLkFNRS5HQkxfQU1F
# JTIwQ1MlMjBDQSUyMDAxKDEpLmNydDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8vL0NO
# PUFNRSUyMENTJTIwQ0ElMjAwMSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JM
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MB0GA1UdDgQWBBRG3SojQLP8bopIpu8+hXTqgV3MLzAOBgNVHQ8BAf8E
# BAMCB4AwVAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5k
# IE9wZXJhdGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjM2MTY3KzQ2MjUxNzCCAdQG
# A1UdHwSCAcswggHHMIIBw6CCAb+gggG7hjxodHRwOi8vY3JsLm1pY3Jvc29mdC5j
# b20vcGtpaW5mcmEvQ1JML0FNRSUyMENTJTIwQ0ElMjAwMS5jcmyGLmh0dHA6Ly9j
# cmwxLmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMS5jcmyGLmh0dHA6Ly9j
# cmwyLmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMS5jcmyGLmh0dHA6Ly9j
# cmwzLmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMS5jcmyGLmh0dHA6Ly9j
# cmw0LmFtZS5nYmwvY3JsL0FNRSUyMENTJTIwQ0ElMjAwMS5jcmyGgbpsZGFwOi8v
# L0NOPUFNRSUyMENTJTIwQ0ElMjAwMSxDTj1CWTJQS0lDU0NBMDEsQ049Q0RQLENO
# PVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3Vy
# YXRpb24sREM9QU1FLERDPUdCTD9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jh
# c2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwHwYDVR0jBBgwFoAU
# G2aiGfyb66XahI8YmOkQpMN7kr0wHwYDVR0lBBgwFgYKKwYBBAGCN1sBAQYIKwYB
# BQUHAwMwDQYJKoZIhvcNAQELBQADggEBAKxYk++FuWDcqQy1CRBI2tTsgkwQ/sR8
# Fi0+xziNF58QdbyUqmA4UGuHBh4T0Av2BLqfWPN8ftPb41rHP5oJCP1dypaC0jOu
# VeErfaKh8QDEDloUxNUkrSZaPV17ksbIvWuVetKFyZVkU6rS8WDkll7bIPYWPUh3
# vM+O1WDQNGA78ybQEvvOzRsSotMeCUa7AS1t1q5Dp2TUVnqjtbWTg0XB6PlhLyux
# VCz4PoX31CpF+IqwzA2w81ltwe4xzENLC24yVjHkmtmuFEAgiPATMaKqZOMeaOhm
# FMeCd0vkYbVA8OtrCHN/ij5+QXpxogz5x8znhMcUKYUU/JTEQZed3RkwggjmMIIG
# zqADAgECAhMfAAAAFLTFH8bygL5xAAAAAAAUMA0GCSqGSIb3DQEBCwUAMDwxEzAR
# BgoJkiaJk/IsZAEZFgNHQkwxEzARBgoJkiaJk/IsZAEZFgNBTUUxEDAOBgNVBAMT
# B2FtZXJvb3QwHhcNMTYwOTE1MjEzMzAzWhcNMjEwOTE1MjE0MzAzWjBBMRMwEQYK
# CZImiZPyLGQBGRYDR0JMMRMwEQYKCZImiZPyLGQBGRYDQU1FMRUwEwYDVQQDEwxB
# TUUgQ1MgQ0EgMDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDVV4EC
# 1vn60PcbgLndN80k3GZh/OGJcq0pDNIbG5q/rrRtNLVUR4MONKcWGyaeVvoaQ8J5
# iYInBaBkaz7ehYnzJp3f/9Wg/31tcbxrPNMmZPY8UzXIrFRdQmCLsj3LcLiWX8BN
# 8HBsYZFcP7Y92R2VWnEpbN40Q9XBsK3FaNSEevoRzL1Ho7beP7b9FJlKB/Nhy0PM
# NaE1/Q+8Y9+WbfU9KTj6jNxrffv87O7T6doMqDmL/MUeF9IlmSrl088boLzAOt2L
# AeHobkgasx3ZBeea8R+O2k+oT4bwx5ZuzNpbGXESNAlALo8HCf7xC3hWqVzRqbdn
# d8HDyTNG6c6zwyf/AgMBAAGjggTaMIIE1jAQBgkrBgEEAYI3FQEEAwIBATAjBgkr
# BgEEAYI3FQIEFgQUkfwzzkKe9pPm4n1U1wgYu7jXcWUwHQYDVR0OBBYEFBtmohn8
# m+ul2oSPGJjpEKTDe5K9MIIBBAYDVR0lBIH8MIH5BgcrBgEFAgMFBggrBgEFBQcD
# AQYIKwYBBQUHAwIGCisGAQQBgjcUAgEGCSsGAQQBgjcVBgYKKwYBBAGCNwoDDAYJ
# KwYBBAGCNxUGBggrBgEFBQcDCQYIKwYBBQUIAgIGCisGAQQBgjdAAQEGCysGAQQB
# gjcKAwQBBgorBgEEAYI3CgMEBgkrBgEEAYI3FQUGCisGAQQBgjcUAgIGCisGAQQB
# gjcUAgMGCCsGAQUFBwMDBgorBgEEAYI3WwEBBgorBgEEAYI3WwIBBgorBgEEAYI3
# WwMBBgorBgEEAYI3WwUBBgorBgEEAYI3WwQBBgorBgEEAYI3WwQCMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjASBgNVHRMBAf8ECDAGAQH/
# AgEAMB8GA1UdIwQYMBaAFCleUV5krjS566ycDaeMdQHRCQsoMIIBaAYDVR0fBIIB
# XzCCAVswggFXoIIBU6CCAU+GI2h0dHA6Ly9jcmwxLmFtZS5nYmwvY3JsL2FtZXJv
# b3QuY3JshjFodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpaW5mcmEvY3JsL2Ft
# ZXJvb3QuY3JshiNodHRwOi8vY3JsMi5hbWUuZ2JsL2NybC9hbWVyb290LmNybIYj
# aHR0cDovL2NybDMuYW1lLmdibC9jcmwvYW1lcm9vdC5jcmyGgapsZGFwOi8vL0NO
# PWFtZXJvb3QsQ049QU1FUk9PVCxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1BTUUsREM9R0JM
# P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxE
# aXN0cmlidXRpb25Qb2ludDCCAasGCCsGAQUFBwEBBIIBnTCCAZkwNwYIKwYBBQUH
# MAKGK2h0dHA6Ly9jcmwxLmFtZS5nYmwvYWlhL0FNRVJPT1RfYW1lcm9vdC5jcnQw
# RwYIKwYBBQUHMAKGO2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2lpbmZyYS9j
# ZXJ0cy9BTUVST09UX2FtZXJvb3QuY3J0MDcGCCsGAQUFBzAChitodHRwOi8vY3Js
# Mi5hbWUuZ2JsL2FpYS9BTUVST09UX2FtZXJvb3QuY3J0MDcGCCsGAQUFBzAChito
# dHRwOi8vY3JsMy5hbWUuZ2JsL2FpYS9BTUVST09UX2FtZXJvb3QuY3J0MIGiBggr
# BgEFBQcwAoaBlWxkYXA6Ly8vQ049YW1lcm9vdCxDTj1BSUEsQ049UHVibGljJTIw
# S2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1B
# TUUsREM9R0JMP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZp
# Y2F0aW9uQXV0aG9yaXR5MA0GCSqGSIb3DQEBCwUAA4ICAQAot0qGmo8fpAFozcIA
# 6pCLygDhZB5ktbdA5c2ZabtQDTXwNARrXJOoRBu4Pk6VHVa78Xbz0OZc1N2xkzgZ
# MoRpl6EiJVoygu8Qm27mHoJPJ9ao9603I4mpHWwaqh3RfCfn8b/NxNhLGfkrc3wp
# 2VwOtkAjJ+rfJoQlgcacD14n9/VGt9smB6j9ECEgJy0443B+mwFdyCJO5OaUP+TQ
# OqiC/MmA+r0Y6QjJf93GTsiQ/Nf+fjzizTMdHggpTnxTcbWg9JCZnk4cC+AdoQBK
# R03kTbQfIm/nM3t275BjTx8j5UhyLqlqAt9cdhpNfdkn8xQz1dT6hTnLiowvNOPU
# kgbQtV+4crzKgHuHaKfJN7tufqHYbw3FnTZopnTFr6f8mehco2xpU8bVKhO4i0yx
# dXmlC0hKGwGqdeoWNjdskyUyEih8xyOK47BEJb6mtn4+hi8TY/4wvuCzcvrkZn0F
# 0oXd9JbdO+ak66M9DbevNKV71YbEUnTZ81toX0Ltsbji4PMyhlTg/669BoHsoTg4
# yoC9hh8XLW2/V2lUg3+qHHQf/2g2I4mm5lnf1mJsu30NduyrmrDIeZ0ldqKzHAHn
# fAmyFSNzWLvrGoU9Q0ZvwRlDdoUqXbD0Hju98GL6dTew3S2mcs+17DgsdargsEPm
# 6I1lUE5iixnoEqFKWTX5j/TLUjGCFSkwghUlAgEBMFgwQTETMBEGCgmSJomT8ixk
# ARkWA0dCTDETMBEGCgmSJomT8ixkARkWA0FNRTEVMBMGA1UEAxMMQU1FIENTIENB
# IDAxAhM2AAABOgNwleIA4C4dAAEAAAE6MA0GCWCGSAFlAwQCAQUAoIGuMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3
# AgEVMC8GCSqGSIb3DQEJBDEiBCA3HyVpbuwti0omXWBiyoDaLccoLjQ/pK+7haE1
# T0cfdDBCBgorBgEEAYI3AgEMMTQwMqAUgBIATQBpAGMAcgBvAHMAbwBmAHShGoAY
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBALF+Qo76
# M/1LMTDlTcshWkhSgssusUSajLqctjMdHGM1brO81l/Z0SrqV/BccdLr/QNB9WpT
# C3BGLOWoWJ5n31exgXcaWyOjfi+NiC3XuLjcxUq0jZ0KCboLQgxGB40idkB6TxzO
# 5ZpONTzz/XrCP3hlIXOlxc/TNWXqYVkO42qJOZ1PkZvdFN3W8pKBXpnHKl+l5F+/
# C2X33xVEXy62u3S4zzAFyk7e7MglT2O5XXmCn6Gb8CQ8t0BOv+ZxSo3Zkwm43lbw
# E3gmW9dTMVyozdOng7yyZ4YiM5ncwvnsPI5w6Df8Nt8RKLw+CwTkFSyqm4ciwnNO
# x3xPdm73zodZf+uhghLxMIIS7QYKKwYBBAGCNwMDATGCEt0wghLZBgkqhkiG9w0B
# BwKgghLKMIISxgIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBVQYLKoZIhvcNAQkQAQSg
# ggFEBIIBQDCCATwCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQgG3z2
# 2jRx4Kha9V78kzqSnIkPtTyJOaJxCY9WsHKipRgCBmAQCMahwxgTMjAyMTAyMDEx
# NzUyMjUuNTIxWjAEgAIB9KCB1KSB0TCBzjELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWljcm9zb2Z0IE9wZXJhdGlvbnMgUHVl
# cnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkY3QTYtRTI1MS0xNTBB
# MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIORDCCBPUw
# ggPdoAMCAQICEzMAAAEli96LbHImMd0AAAAAASUwDQYJKoZIhvcNAQELBQAwfDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTkxMjE5MDExNDU4WhcNMjEw
# MzE3MDExNDU4WjCBzjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEpMCcGA1UECxMgTWljcm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28xJjAk
# BgNVBAsTHVRoYWxlcyBUU1MgRVNOOkY3QTYtRTI1MS0xNTBBMSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEA0HsfY3ZgW+zhycEmJjFKK2TcAHL/Fct+k5Sbs3FcexvpRard
# s41jjJUjjJJtV6ALifFWeUoQXnQA1wxgysRzWYS7txFvMeaLfyDpOosy05QBbbyF
# zoM17Px2jjO9lxyspDGRwHS/36WbQEjOT2pZrF1+DpfJV5JvY0eeSuegu6vfoQ1P
# trYxh2hNWVpWm5TVFwYWmYLQiQnetFMmb4CO/7jc3Gn49P1cNm2orfZwwFXduMrf
# 1wmZx2N8l+2bB4yLh6bJfj6Q12otQ8HvadK8gmbJfUjjB3sbSB3vapU27VmCfFrV
# i6B/XRDEMVS55jzwzlZgY+y2YUo4t/DfVac/xQIDAQABo4IBGzCCARcwHQYDVR0O
# BBYEFPOqyuUHJvkBOTQVxgjyIggXQyT4MB8GA1UdIwQYMBaAFNVjOlyKMZDzQ3t8
# RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNy
# bDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0MAwG
# A1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQAD
# ggEBAJMcWTxhICIAIbKmTU2ZOfFdb0IieY2tsR5eU6hgOh8I+UoqC4NxUi4k5hlf
# gbRZaWFLZJ3geI62bLjaTLX20zHRu6f8QMiFbcL15016ipQg9U/S3K/eKVXncxxi
# cy9U2DUMmSQaLgn85IJM3HDrhTn3lj35zE4iOVAVuTnZqMhz0Fg0hh6G6FtXUyql
# 3ibblQ02Gx0yrOM43wgTBY5spUbudmaYs/vTAXkY+IgHqLtBf98byM3qaCCoFFgm
# fZplYlhJFcArUxm1fHiu9ynhBNLXzFP2GNlJqBj3PGMG7qwxH3pXoC1vmB5H63Bg
# BpX7QpqrTnTi3oIS6BtFG8fwe7EwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0G
# CSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3
# PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMw
# VyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijG
# GvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/
# 9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9
# pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUB
# BAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcU
# AgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8G
# A1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcu
# AzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9k
# b2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwA
# XwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0B
# AQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LF
# Zslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPle
# FzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6
# AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQ
# jP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9Mal
# CpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacR
# y5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo
# +KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZ
# eodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMR
# ZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/
# XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341Hgi62jbb01+P3nSISRKhggLSMIIC
# OwIBATCB/KGB1KSB0TCBzjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEpMCcGA1UECxMgTWljcm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28x
# JjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkY3QTYtRTI1MS0xNTBBMSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBF
# 0y/hUG3NhvtzF17yESla9qFwp6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA48Jv0zAiGA8yMDIxMDIwMTE2MTcy
# M1oYDzIwMjEwMjAyMTYxNzIzWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDjwm/T
# AgEAMAoCAQACAhT4AgH/MAcCAQACAhMFMAoCBQDjw8FTAgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQEFBQADgYEAV0SqsppTP4SFEPhCqjkCbQeGOldkA21lG7jXiNEBfHE+
# o2XZd4dC3zpqjrnTGAyBdCnorpfZGjULIu3qJ+/BsfC6/YmSOMKb3+ix2duBmN7N
# SNZm1bV7Fksln91JPyt5jMShr7bTCKaxCraftbPjmVglIQqy+3KirTuV+XSWK70x
# ggMNMIIDCQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAA
# ASWL3otsciYx3QAAAAABJTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCDReHil7wwPf9+nksj4ZcWg
# /W4FOIr3718z2PJ/RGXHvTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIF3f
# xrIubzBf+ol9gg4flX5i+Ub6mhZBcJboso3vQfcOMIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAEli96LbHImMd0AAAAAASUwIgQgiKOc
# xCuj780u2HDVxSJtwtn2k9jGs11AdH+ClzWXAZ8wDQYJKoZIhvcNAQELBQAEggEA
# bGyyK7fU0+x6BnPwI319HIhQUDIc+AneDEcMBT9B8Vas36UKBSRrcMgsXMcsvUl1
# bmo+cR6QHvevlZLp6HDZKb5MqmwfeH0wJ/dEw6A7cHdgMwPYfr6taLd2GT/3vwK5
# Rlv9cPIfAH7wHdECCyfQv9+bVm2cGerMmv31X5swUbVWAblFdWueTIpbR5Z9nMtg
# z/7YT7d/QV1ez6vtjq1i/+G/isNzrb4lg0+sHgn9NWN6QXKptpc6wrC4YaQ/rHO1
# A5WrS0Brw9PVxvg1dTGAo+nTC3hojAHi5LyVp0SNbiIj9UqzOxefipasm3hgCg5K
# N355vdXnQsqRKPWnf+Wz4Q==
# SIG # End signature block
