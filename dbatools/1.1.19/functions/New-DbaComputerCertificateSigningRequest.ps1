function New-DbaComputerCertificateSigningRequest {
    <#
    .SYNOPSIS
        Creates a new computer certificate signing request. Useful for offline servers and Forcing Encryption.

    .DESCRIPTION
        Creates a new computer certificate signing request that is compatible with SQL Server.

        By default, a key with a length of 1024 and a friendly name of the machines FQDN is generated.

    .PARAMETER ComputerName
       The target SQL Server instance or instances. Defaults to localhost. If target is a cluster, you must also specify ClusterInstanceName (see below)

    .PARAMETER Credential
        Allows you to login to $ComputerName using alternative credentials.

    .PARAMETER Path
        The folder to export to.

    .PARAMETER ClusterInstanceName
        When creating certs for a cluster, use this parameter to create the certificate for the cluster node name. Use ComputerName for each of the nodes.

    .PARAMETER FriendlyName
        The FriendlyName listed in the certificate. This defaults to the FQDN of the $ComputerName

    .PARAMETER KeyLength
        The length of the key - defaults to 1024

    .PARAMETER Dns
        Specify the Dns entries listed in SAN. By default, it will be ComputerName + FQDN, or in the case of clusters, clustername + cluster FQDN.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .NOTES
        Tags: Certificate
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaComputerCertificateSigningRequest

    .EXAMPLE
        PS C:\> New-DbaComputerCertificate

        Creates a computer certificate signing request for the local machine with the keylength of 1024.

    .EXAMPLE
        PS C:\> New-DbaComputerCertificate -ComputerName Server1

        Creates a computer certificate signing request for server1 with the keylength of 1024.

    .EXAMPLE
        PS C:\> New-DbaComputerCertificate -ComputerName sqla, sqlb -ClusterInstanceName sqlcluster -KeyLength 4096

        Creates a computer certificate signing request for sqlcluster with the keylength of 4096.

    .EXAMPLE
        PS C:\> New-DbaComputerCertificate -ComputerName Server1 -WhatIf

        Shows what would happen if the command were run

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "", Justification = "PSSA Rule Ignored by BOH")]
    param (
        [parameter(ValueFromPipeline)]
        [DbaInstance[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [string]$ClusterInstanceName,
        [string]$Path = (Get-DbatoolsConfigValue -FullName 'Path.DbatoolsExport'),
        [string]$FriendlyName = "SQL Server",
        [int]$KeyLength = 1024,
        [string[]]$Dns,
        [switch]$EnableException
    )
    begin {
        $englishCodes = 9, 1033, 2057, 3081, 4105, 5129, 6153, 7177, 8201, 9225
        if ($englishCodes -notcontains (Get-DbaCmObject -ClassName Win32_OperatingSystem).OSLanguage) {
            Stop-Function -Message "Currently, this command is only supported in English OS locales. OS Locale detected: $([System.Globalization.CultureInfo]::GetCultureInfo([int](Get-DbaCmObject Win32_OperatingSystem).OSLanguage).DisplayName)`nWe apologize for the inconvenience and look into providing universal language support in future releases."
            return
        }

        function GetHexLength {
            [cmdletbinding()]
            param(
                [int]$strLen
            )
            $hex = [String]::Format("{0:X2}", $strLen)

            if ($strLen -gt 127) { [String]::Format("{0:X2}", 128 + ($hex.Length / 2)) + $hex }
            else { $hex }
        }

        function Get-SanExt {
            [cmdletbinding()]
            param(
                [string[]]$hostName
            )
            # thanks to Lincoln of
            # https://social.technet.microsoft.com/Forums/windows/en-US/f568edfa-7f93-46a4-aab9-a06151592dd9/converting-ascii-to-asn1-der

            $temp = ''
            foreach ($fqdn in $hostName) {
                # convert each character of fqdn to hex
                $hexString = ($fqdn.ToCharArray() | ForEach-Object { [String]::Format("{0:X2}", [int]$_) }) -join ''

                # length of hex fqdn, in hex
                $hexLength = GetHexLength ($hexString.Length / 2)

                # concatenate special code 82, hex length, hex string
                $temp += "82${hexLength}${hexString}"
            }
            # calculate total length of concatenated string, in hex
            $totalHexLength = GetHexLength ($temp.Length / 2)
            # concatenate special code 30, hex length, hex string
            $temp = "30${totalHexLength}${temp}"
            # convert to binary
            $bytes = $(
                for ($i = 0; $i -lt $temp.Length; $i += 2) {
                    [byte]"0x$($temp.SubString($i, 2))"
                }
            )
            # convert to base 64
            $base64 = [Convert]::ToBase64String($bytes)
            # output in proper format
            for ($i = 0; $i -lt $base64.Length; $i += 64) {
                $line = $base64.SubString($i, [Math]::Min(64, $base64.Length - $i))
                if ($i -eq 0) { "2.5.29.17=$line" }
                else { "_continue_=$line" }
            }
        }
    }

    process {
        if (Test-FunctionInterrupt) {
            return
        }

        if (-not (Test-ElevationRequirement -ComputerName $env:COMPUTERNAME)) {
            return
        }

        # uses dos command locally

        foreach ($computer in $ComputerName) {
            $stepCounter = 0

            if (-not $secondaryNode) {

                if ($ClusterInstanceName) {
                    if ($ClusterInstanceName -notmatch "\.") {
                        $fqdn = "$ClusterInstanceName.$env:USERDNSDOMAIN"
                    } else {
                        $fqdn = $ClusterInstanceName
                    }
                } else {
                    $resolved = Resolve-DbaNetworkName -ComputerName $computer.ComputerName -WarningAction SilentlyContinue

                    if (-not $resolved) {
                        $fqdn = "$ComputerName.$env:USERDNSDOMAIN"
                        Write-Message -Level Warning -Message "Server name cannot be resolved. Guessing it's $fqdn"
                    } else {
                        $fqdn = $resolved.fqdn
                    }
                }

                $certDir = "$Path\$fqdn"
                $certCfg = "$certDir\request.inf"
                $certCsr = "$certDir\$fqdn.csr"

                if (Test-Path($certDir)) {
                    Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Deleting files from $certDir"
                    $null = Remove-Item "$certDir\*.*"
                } else {
                    Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Creating $certDir"
                    $null = New-Item -Path $certDir -ItemType Directory -Force
                }

                # Make sure output is compat with clusters
                $shortName = $fqdn.Split(".")[0]

                if (-not $dns) {
                    $dns = $shortName, $fqdn
                }

                $san = Get-SanExt $dns
                # Write config file
                Set-Content $certCfg "[Version]"
                Add-Content $certCfg 'Signature="$Windows NT$"'
                Add-Content $certCfg "[NewRequest]"
                Add-Content $certCfg "Subject = ""CN=$fqdn"""
                Add-Content $certCfg "KeySpec = 1"
                Add-Content $certCfg "KeyLength = $KeyLength"
                Add-Content $certCfg "Exportable = TRUE"
                Add-Content $certCfg "MachineKeySet = TRUE"
                Add-Content $certCfg "FriendlyName=""$FriendlyName"""
                Add-Content $certCfg "SMIME = False"
                Add-Content $certCfg "PrivateKeyArchive = FALSE"
                Add-Content $certCfg "UserProtected = FALSE"
                Add-Content $certCfg "UseExistingKeySet = FALSE"
                Add-Content $certCfg "ProviderName = ""Microsoft RSA SChannel Cryptographic Provider"""
                Add-Content $certCfg "ProviderType = 12"
                if ($SelfSigned) {
                    Add-Content $certCfg "RequestType = Cert"
                } else {
                    Add-Content $certCfg "RequestType = PKCS10"
                }
                Add-Content $certCfg "KeyUsage = 0xa0"
                Add-Content $certCfg "[EnhancedKeyUsageExtension]"
                Add-Content $certCfg "OID=1.3.6.1.5.5.7.3.1"
                Add-Content $certCfg "[Extensions]"
                Add-Content $certCfg $san
                Add-Content $certCfg "Critical=2.5.29.17"


                if ($PScmdlet.ShouldProcess("local", "Creating certificate for $computer")) {
                    Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Running: certreq -new $certCfg $certCsr"
                    $null = certreq -new $certCfg $certCsr
                }
                Get-ChildItem $certCfg, $certCsr
            }
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhY9oNvn32YaRb3kVKuXD9WrB
# +zGgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMxMDEw
# NjAwMDAwMFowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2UtAxQ
# tSYQ/h3Ib5FrDJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4CGPN4
# bbx9+cdtCT2+anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xObTOK
# fF1FLUuxUOZBOjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wODMSlK
# XAwxikqMiMX3MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwfoYer
# vnpbCiAvSwnJlaeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgwggG0
# MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMEEGA1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEWG2h0
# dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4prtLk
# YaWyoiWyyBc1bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYDVR0f
# BGowaDAyoDCgLoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJl
# ZC10cy5jcmwwMqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtdHMuY3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NB
# LmNydDANBgkqhkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0CiNH
# o6uS0iXEcFm+FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1UUp4
# eTZ6J7fz51Kfk6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2QzI2h
# F3MN9PNlOXBL85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnYIpp1
# FUL1LTI4gdr0YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oNcX6X
# t/Q/hOvB46NJofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBRowggQC
# oAMCAQICEAMFu4YhsKFjX7/erhIE520wDQYJKoZIhvcNAQELBQAwcjELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUg
# U2lnbmluZyBDQTAeFw0yMDA1MTIwMDAwMDBaFw0yMzA2MDgxMjAwMDBaMFcxCzAJ
# BgNVBAYTAlVTMREwDwYDVQQIEwhWaXJnaW5pYTEPMA0GA1UEBxMGVmllbm5hMREw
# DwYDVQQKEwhkYmF0b29sczERMA8GA1UEAxMIZGJhdG9vbHMwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQC8v2N7q+O/vggBtpjmteofFo140k73JXQ5sOD6
# QLzjgija+scoYPxTmFSImnqtjfZFWmucAWsDiMVVro/6yGjsXmJJUA7oD5BlMdAK
# fuiq4558YBOjjc0Bp3NbY5ZGujdCmsw9lqHRAVil6P1ZpAv3D/TyVVq6AjDsJY+x
# rRL9iMc8YpD5tiAj+SsRSuT5qwPuW83ByRHqkaJ5YDJ/R82ZKh69AFNXoJ3xCJR+
# P7+pa8tbdSgRf25w4ZfYPy9InEvsnIRVZMeDjjuGvqr0/Mar73UI79z0NYW80yN/
# 7VzlrvV8RnniHWY2ib9ehZligp5aEqdV2/XFVPV4SKaJs8R9AgMBAAGjggHFMIIB
# wTAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQU8MCg
# +7YDgENO+wnX3d96scvjniIwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5kaWdp
# Y2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcGCWCG
# SAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20v
# Q1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmluZ0NB
# LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQCPzflwlQwf1jak
# EqymPOc0nBxiY7F4FwcmL7IrTLhub6Pjg4ZYfiC79Akz5aNlqO+TJ0kqglkfnOsc
# jfKQzzDwcZthLVZl83igzCLnWMo8Zk/D2d4ZLY9esFwqPNvuuVDrHvgh7H6DJ/zP
# Vm5EOK0sljT0UQ6HQEwtouH5S8nrqCGZ8jKM/+DeJlm+rCAGGf7TV85uqsAn5JqD
# En/bXE1AlyG1Q5YiXFGS5Sf0qS4Nisw7vRrZ6Qc4NwBty4cAYjzDPDixorWI8+FV
# OUWKMdL7tV8i393/XykwsccCstBCp7VnSZN+4vgzjEJQql5uQfysjcW9rrb/qixp
# csPTKYRHMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFMTCC
# BBmgAwIBAgIQCqEl1tYyG35B5AXaNpfCFTANBgkqhkiG9w0BAQsFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMTYwMTA3MTIwMDAwWhcNMzEwMTA3MTIwMDAwWjByMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1waW5n
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvdAy7kvNj3/dqbqC
# mcU5VChXtiNKxA4HRTNREH3Q+X1NaH7ntqD0jbOI5Je/YyGQmL8TvFfTw+F+CNZq
# FAA49y4eO+7MpvYyWf5fZT/gm+vjRkcGGlV+Cyd+wKL1oODeIj8O/36V+/OjuiI+
# GKwR5PCZA207hXwJ0+5dyJoLVOOoCXFr4M8iEA91z3FyTgqt30A6XLdR4aF5FMZN
# JCMwXbzsPGBqrC8HzP3w6kfZiFBe/WZuVmEnKYmEUeaC50ZQ/ZQqLKfkdT66mA+E
# f58xFNat1fJky3seBdCEGXIX8RcG7z3N1k3vBkL9olMqT4UdxB08r8/arBD13ays
# 6Vb/kwIDAQABo4IBzjCCAcowHQYDVR0OBBYEFPS24SAd/imu0uRhpbKiJbLIFzVu
# MB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8v
# Y3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqg
# OKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMFAGA1UdIARJMEcwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIB
# FhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAQEAcZUS6VGHVmnN793afKpjerN4zwY3QITvS4S/ys8DAv3F
# p8MOIEIsr3fzKx8MIVoqtwU0HWqumfgnoma/Capg33akOpMP+LLR2HwZYuhegiUe
# xLoceywh4tZbLBQ1QwRostt1AuByx5jWPGTlH0gQGF+JOGFNYkYkh2OMkVIsrymJ
# 5Xgf1gsUpYDXEkdws3XVk4WTfraSZ/tTYYmo9WuWwPRYaQ18yAGxuSh1t5ljhSKM
# Ycp5lH5Z/IwP42+1ASa2bKXuh1Eh5Fhgm7oMLSttosR+u8QlK0cCCHxJrhO24XxC
# QijGGFbPQTS2Zl22dHv1VjMiLyI2skuiSpXY9aaOUjGCBFwwggRYAgEBMIGGMHIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJ
# RCBDb2RlIFNpZ25pbmcgQ0ECEAMFu4YhsKFjX7/erhIE520wCQYFKw4DAhoFAKB4
# MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkE
# MRYEFM3l1JZAS9SmjMp3p+0c00cJGK8DMA0GCSqGSIb3DQEBAQUABIIBAD0K27sD
# GTNyAtR2eF4otugVbfubOV8iDxSx71lzv3/7As8uzMui12KDi2zVDhiwWOuISetD
# TX2KDvCb2fxZygM2J9FullNBbFZkyYbF36jIZzqxUjL/1SjILoYSIekHVftHIs66
# A+dwheIpif+FF3pvpaBGYMfP3E3SQC8UC61PedUqiQobNvviXYtb6Qks7on6/G9S
# lx7xEz3+f8RVYmGolvogdzzqB2LEEpuorZoGjGeMDViR64rfgzv/o+rLyp7ThuZP
# qgJ8Zp2galX4WiOCTtOL7wWFHvvYrkA7SnpOHgTJR7Ji3ujOwr2guHg83QPv42kd
# aphprr56g97pFsmhggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDkxODEyNDc0MFowLwYJKoZIhvcNAQkEMSIEIN9pVxIoyCDJN0Kf6IDJw7ORNb1n
# /k0bxLxg/NnuAzeXMA0GCSqGSIb3DQEBAQUABIIBAAgxxOiYcRI8lP8p4h2tiURV
# 4736Uk+sEw5VIOgJG5Ge46IZy4P/NlPmjfiSYZyoz27CXP32mk2lDATL8ssxdSar
# nQqZsr3RklpK3x5ddEpC9MytpnlAPayx7Pw41kMG0uMiJHElraa72YDwBKw+RzpI
# xRFZ5NVHCqprX4bzulazbL3vwanpWbkmCGeZ8chQjXDiS38UnAPTzaE1M0Fy/fYV
# TlBXCpGi1GPnf6MsPWIR2V0bKloVo5LxAIsPJi8xvn6vlqV3ZxXsBO1r+b7JhJv2
# 6GjZko29O1KzLdJ/fS/Sm+3MF6Oz66whTm/fsCbD9QX7HENz9bJ/lHoW1F+xO6A=
# SIG # End signature block
