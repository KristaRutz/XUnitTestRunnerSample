Param([string]$Version)

Write-Host "Downloading the latest version of nuget.exe . . . " -NoNewline
$nuget = Join-Path -Path $PSScriptRoot -ChildPath "nuget.exe"
$nugetEtag = $nuget + ".etag"
$headers = @{}
if ((Test-Path $nuget) -and (Test-Path $nugetEtag))
{
    $headers.Add("If-None-Match", [System.IO.File]::ReadAllText($nugetEtag))
}
try
{
    $response = Invoke-WebRequest -Headers $headers -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -PassThru -OutFile $nuget -UseBasicParsing
}
catch [System.Net.WebException]
{
    $response = $_.Exception.Response
}
if ($response.StatusCode -eq 200)
{
    Unblock-File $nuget
    [System.IO.File]::WriteAllText($nugetEtag, $response.Headers["ETag"])
    Write-Host "download complete."
}
elseif ($response.StatusCode -eq 304)
{
    Write-Host "app is up to date."
}
elseif (Test-Path $nuget)
{
    Write-Host "app may be out of date." -ForegroundColor Yellow
}
else
{
    Write-Host "failed." -ForegroundColor Red
    Write-Host
    throw "Could not download a copy of nuget.exe to bootstrap. Check your internet connection."
}

Write-Host "Installing credential provider . . . " -NoNewline
$providerName = "CredentialProvider.VSS.exe"
$provider = Join-Path -Path $PSScriptRoot -ChildPath $providerName
$nugetFeed = "https://api.nuget.org/v3/index.json"
$packages = Join-Path -Path $PSScriptRoot -ChildPath "packages"
$nugetOut = &$nuget install Microsoft.VisualStudio.Services.NuGet.CredentialProvider -Source $nugetFeed -OutputDirectory $packages -NonInteractive 2>&1
if ($?)
{
    $providerSource = Get-ChildItem -Filter $providerName -Path $packages -Recurse | Select-Object -Last 1
    Copy-Item -Path $providerSource.FullName -Destination $PSScriptRoot
    Write-Host "installed."
}
elseif(Test-Path $provider)
{
    Write-Host "package may be out of date." -ForegroundColor Yellow
}
else
{
    Write-Host "failed." -ForegroundColor Red
    Write-Host
    throw "Could not install credential provider for Azure DevOps feeds. Check your internet connection."
}

Write-Host "Installing Geneva PowerShell Cmdlets . . . " -NoNewline
$cmdletsPackage = "GenevaWarmPathPowerShellCmdlets"
$genevaFeed = "https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json"
if (-not $Version)
{
    $nugetOut = &$nuget list $cmdletsPackage -Source $genevaFeed -NonInteractive 2>&1
    if (-not $?)
    {
        Write-Host "failed." -ForegroundColor Red
        Write-Host
        throw "Could not determine the latest version of $cmdletsPackage. Check your access to $genevaFeed."
    }
    $Version = $nugetOut | Select-Object -Last 1
    $Version = $Version.Split(' ') | Select-Object -Index 1
}
$azureFeed = "https://msazure.pkgs.visualstudio.com/DefaultCollection/_apis/packaging/Official/nuget/index.json"
$nugetOut = &$nuget install GenevaWarmPathPowerShellCmdlets -Version $Version -Source $genevaFeed -Source $nugetFeed -FallbackSource $azureFeed -OutputDirectory $packages -NonInteractive 2>&1
if (-not $?)
{
    Write-Host "failed." -ForegroundColor Red
    Write-Host
    throw "Could not install GenevaWarmPathPowerShellCmdlets $Version. Make sure the version exists in $genevaFeed. Also, check your access to $azureFeed."
}
Write-Host "installed (version $Version)."
$genevaModule = Get-Item "$PSScriptRoot\packages\GenevaWarmPathPowerShellCmdlets.$Version\lib\net452\GenevaWarmPathClient.psm1"
Write-Host "Importing module . . . " -NoNewline
$env:Path = $env:Path + ";" + $genevaModule.DirectoryName
$env:PSModulePath = $env:PSModulePath + ";" + $genevaModule.DirectoryName
Push-Location $genevaModule.DirectoryName
Import-Module $genevaModule.FullName
Pop-Location
$host.ui.RawUI.WindowTitle = "Geneva Command Shell"
Write-Host "complete."
Write-Host "Ready to run commands."
Write-Host

# SIG # Begin signature block
# MIInPAYJKoZIhvcNAQcCoIInLTCCJykCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAXs0s4UIzgPMgN
# odPRdQabx8vyKHigCgD3LD0SWlCPZ6CCEWkwggh7MIIHY6ADAgECAhM2AAABOgNw
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
# AgEVMC8GCSqGSIb3DQEJBDEiBCAJ9xngKO0adqL1NLrbEsTMZRf94f6Wc12jTuM1
# f+3wrjBCBgorBgEEAYI3AgEMMTQwMqAUgBIATQBpAGMAcgBvAHMAbwBmAHShGoAY
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAId9Ihr3
# dY9gBeJIGKaUjI3SMx4bxzebYhrNQ47GsXqv0W08YHQBwgnY4RumjBQ2kCHntCV0
# YBa2AiavS8phpXyBHmUr+ylwLBwrwtVTlTiCFBPh5eD/rXTpQBiJaPeHf1/1N2Om
# sDn8EA6vI7zYXnmEaHlDSP9LWayb3U2WCfg6u14ju65pFczQlmQxKSd56KTe+qWF
# yuiHvy98Y3puzbd6c68DpW/PsI3v7teWRXcz6rzKxI8oPOQosHfE5z89BJGir/qE
# XuXdthJWwuUz/UYcgeS8Ppd/fbmv3L0+vTvAs8YJhNidFh3wVSsr+CUPvEEbSGhn
# zuxFcpWkjA0tkQKhghLxMIIS7QYKKwYBBAGCNwMDATGCEt0wghLZBgkqhkiG9w0B
# BwKgghLKMIISxgIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBVQYLKoZIhvcNAQkQAQSg
# ggFEBIIBQDCCATwCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQg8Jdb
# GcRd7xlwpdcz0VQgoXeEXyUM7Wu7mGs2DbLT0ywCBmAQCMagWxgTMjAyMTAyMDEx
# NzUxNDkuOTUzWjAEgAIB9KCB1KSB0TCBzjELMAkGA1UEBhMCVVMxEzARBgNVBAgT
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
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCA7K5BTOH8p8fBQUdTV1/9g
# AVbMMD1YDWazDw7szbG/uzCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIF3f
# xrIubzBf+ol9gg4flX5i+Ub6mhZBcJboso3vQfcOMIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAEli96LbHImMd0AAAAAASUwIgQgiKOc
# xCuj780u2HDVxSJtwtn2k9jGs11AdH+ClzWXAZ8wDQYJKoZIhvcNAQELBQAEggEA
# Eh1D/dtzJhUF/SIN84I4T7df2sjvO6sWgGdIaFg09BFH4Hip6IsGcu/macYA0AyQ
# 2DiRPfgvI0VN9ZqLAJSnuJFYoPrRMvDiT1bov5LTyY5KPdlsIerzRZhOvxTa93c0
# r/A0cvw4O6XiTqX4zwLZFAIlNP/J/MgmgabiLPm3LMUMaLpojSB3NbA6xhZ2WsT/
# eQiYy1SepXENRwLL7UUWz5o7RGAjCzsvKWMK4V0mbyhxhVBUGGt4gawepFq1z/gX
# 8VW9NJEYOlvjKcKCsjB6wz7YPUuuFltIzxhqobCz3mPNL2y7betw522tDUASGX7t
# encmQ3BoH8EeLbN7awy5aw==
# SIG # End signature block
