function Get-DbaProductKey {
    <#
    .SYNOPSIS
        Gets SQL Server Product Keys from local or destination SQL Servers.

    .DESCRIPTION
        This command find the product key for all installed instances. Clustered instances are supported as well.

    .PARAMETER ComputerName
        The target SQL Server instance or instances.

    .PARAMETER Credential
        Login to the target Windows instance using alternative credentials. Windows Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER SqlCredential
        This command logs into the SQL instance to gather additional information.

        Use this parameter to connect to the discovered SQL instances using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: ProductKey
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaProductKey

    .EXAMPLE
        PS C:\> Get-DbaProductKey -ComputerName winxp, sqlservera, sqlserver2014a, win2k8

        Gets SQL Server versions, editions and product keys for all instances within each server or workstation.

    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline, Mandatory)]
        [Alias("SqlInstance")]
        [DbaInstanceParameter[]]$ComputerName,
        [PSCredential]$SqlCredential,
        [PSCredential]$Credential,
        [switch]$EnableException
    )

    begin {
        $scriptBlock = {
            $versionMajor = $args[0]
            $instanceReg = $args[1]
            $edition = $args[2]

            Function Unlock-SqlInstanceKey {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory)]
                    [byte[]]$data,
                    [int]$version
                )
                try {
                    if ($version -ge 11) {
                        $binArray = ($data)[0 .. 66]
                    } else {
                        $binArray = ($data)[52 .. 66]
                    }
                    $charsArray = "B", "C", "D", "F", "G", "H", "J", "K", "M", "P", "Q", "R", "T", "V", "W", "X", "Y", "2", "3", "4", "6", "7", "8", "9"

                    $isNKey = ([math]::truncate($binArray[14] / 0x6) -band 0x1) -ne 0
                    if ($isNKey) {
                        $binArray[14] = $binArray[14] -band 0xF7
                    }
                    $last = 0

                    for ($i = 24; $i -ge 0; $i--) {
                        $k = 0
                        for ($j = 14; $j -ge 0; $j--) {
                            $k = $k * 256 -bxor $binArray[$j]
                            $binArray[$j] = [math]::truncate($k / 24)
                            $k = $k % 24
                        }
                        $productKey = $charsArray[$k] + $productKey
                        $last = $k
                    }

                    if ($isNKey) {
                        $part1 = $productKey.Substring(1, $last)
                        $part2 = $productKey.Substring(1, $productKey.Length - 1)
                        if ($last -eq 0) {
                            $productKey = "N" + $part2
                        } else {
                            $productKey = $part2.Insert($part2.IndexOf($part1) + $part1.Length, "N")
                        }
                    }

                    $productKey = $productKey.Insert(20, "-").Insert(15, "-").Insert(10, "-").Insert(5, "-")
                } catch {
                    $productkey = "Cannot decode product key."
                }
                return $productKey
            }
            $localmachine = [Microsoft.Win32.RegistryHive]::LocalMachine
            $defaultview = [Microsoft.Win32.RegistryView]::Default
            $reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey($localmachine, $defaultview)

            switch ($versionMajor) {
                9 {
                    $sqlversion = "SQL Server 2005 $servicePack"
                    $findkeys = $reg.OpenSubKey("$($instanceReg.Path)\ProductID", $false)
                    foreach ($findkey in $findkeys.GetValueNames()) {
                        if ($findkey -like "DigitalProductID*") {
                            $key = @("$($instanceReg.Path)\ProductID\$findkey")
                        }
                    }
                }
                10 {
                    $sqlversion = "SQL Server 2008 $servicePack"
                    if ($server.VersionMinor -eq 50) {
                        $sqlversion = "SQL Server 2008 R2 $servicePack"
                    }
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID")
                }
                11 {
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID", "$($instanceReg.Path)\ClientSetup\DigitalProductID")
                    $sqlversion = "SQL Server 2012 $servicePack"
                }
                12 {
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID", "$($instanceReg.Path)\ClientSetup\DigitalProductID")
                    $sqlversion = "SQL Server 2014 $servicePack"
                }
                13 {
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID", "$($instanceReg.Path)\ClientSetup\DigitalProductID")
                    $sqlversion = "SQL Server 2016 $servicePack"
                }
                14 {
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID", "$($instanceReg.Path)\ClientSetup\DigitalProductID")
                    $sqlversion = "SQL Server 2017 $servicePack"
                }
                15 {
                    $key = @("$($instanceReg.Path)\Setup\DigitalProductID", "$($instanceReg.Path)\ClientSetup\DigitalProductID")
                    $sqlversion = "SQL Server 2019 $servicePack"
                }
                default {
                    Stop-Function -Message "SQL version not currently supported." -Continue
                }
            }
            if ($edition -notlike "*Express*") {
                $sqlkey = ''
                foreach ($k in $key) {
                    $subkey = Split-Path $k
                    $binaryvalue = Split-Path $k -Leaf
                    try {
                        $binarykey = $($reg.OpenSubKey($subkey)).GetValue($binaryvalue)
                        break
                    } catch {
                        $binarykey = $null
                    }
                }

                if ($null -eq $binarykey) {
                    $sqlkey = "Could not read Product Key from registry on $env:COMPUTERNAME"
                } else {
                    try {
                        $sqlkey = Unlock-SqlInstanceKey $binarykey $versionMajor
                    } catch {
                        $sqlkey = "Unable to unlock key"
                    }
                }
            } else {
                $sqlkey = "SQL Server Express Edition"
            }

            [pscustomobject]@{
                Version = $sqlversion
                Key     = $sqlkey
            }
            $reg.Close()
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            try {
                $registryroot = Get-DbaRegistryRoot -ComputerName $computer.ComputerName -Credential $Credential -EnableException
            } catch {
                Stop-Function -Message "Can't access registry for $($computer.ComputerName). Is the Remote Registry service started?" -Continue
            }

            if (-not $registryroot) {
                Stop-Function -Message "No instances found on $($computer.ComputerName)" -Continue
            }

            # Get Product Keys for all instances on the server.
            foreach ($instanceReg in $registryroot) {
                try {
                    $server = Connect-DbaInstance -SqlInstance $instanceReg.SqlInstance -SqlCredential $SqlCredential -MinimumVersion 10
                } catch {
                    Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instanceReg.SqlInstance -Continue
                }

                $servicePack = $server.ProductLevel
                $versionMajor = $server.VersionMajor
                Write-Message -Level Debug -Message "$instance $instanceName version is $($server.VersionMajor)"

                try {
                    $results = Invoke-Command2 -ComputerName $computer.ComputerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $server.VersionMajor, $instanceReg, $server.Edition
                } catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_
                }

                [pscustomobject]@{
                    ComputerName = $server.ComputerName
                    InstanceName = $server.ServiceName
                    SqlInstance  = $server.DomainInstanceName
                    Version      = $results.Version
                    Edition      = $server.Edition
                    Key          = $results.Key
                }
            }
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULObazIXInWFbwjGKUtfqtDOc
# M6OgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFILK4VED59q1an/A5e5xDANC6tRUMA0GCSqGSIb3DQEBAQUABIIBAA8zPNFi
# oOBHcbnPUpsKXndeYs4AIByzd3WQ2iXjAkpOSxka1jmWgdSZ5cl3kS1+kD785SOd
# NRfkCxuWVaw5jEsVoqSzRmpi4todbtAK/NlntZxK3BIOZV990fJQpVxcRzzLoR1m
# J4Oh0CDImZuqT/PXyt3E+Yt1xa6mS4Jo24TlWTVb6m6NCk2DhOT3OrJ5+ANoFH5A
# Ep3iLO+x1bmPBSZ+Te8p38ZAw6oW4ejHklLev9gp0NYVD9YmXQWSPJfjYNe+A1Ty
# AWjJM4iCn/7l0UBSBXUpjEaZPjDozrDX/WU5UzCjjlUEcHJcL/nMWMjfN1Zl8yyD
# pBRfSmtGEvcNyNWhggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDkxODEyNDcyNVowLwYJKoZIhvcNAQkEMSIEIKcDnnG8PViTkb4rIlIv1kUt5ARx
# uRDvTRQpgvQg9R5ZMA0GCSqGSIb3DQEBAQUABIIBAEc070A8w+AmPPQiHEk6NtHU
# rvCUq7Q+QBAYiRc2qxbwE5HPtK5QpUF3FowJm2ryNIpr/Po96JMdqf1Mtaiy7l1z
# Q2XYJrjZLXoWcxI8SjV/kUFQQRtdjqD/oea94GOskCFkncp5GzBy1ncKC1xfsaDT
# oYDiLirEB0xxhjVAuGJ3GyX1vTuoDIkxtQL0uS/2tR7tfhsWGQb37GFJNMp/x3lG
# 8YN0y52j6TUlb3V7kIn5mi3zn+tekvB2a35SnkN4EWaej15GsKuCDGs9LgTpP/H6
# R/avntXmWOd2aOlL+D+Ro3kG6BYSXyYEAi/tGdhBctd2ufyh4FQxH2KePYAEqoQ=
# SIG # End signature block
