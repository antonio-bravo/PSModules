function Get-SqlInstanceUpdate {
    <#
    Originally based on https://github.com/adbertram/PSSqlUpdater
    Internal function. Provides information on the target update version for a specific set of SQL Server instances based on current and target SQL Server levels.
    Component parameter is using the output object of Get-SqlInstanceComponent.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Latest')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [DbaInstanceParameter]$ComputerName,
        [pscredential]$Credential,
        [Parameter(Mandatory, ParameterSetName = 'Latest')]
        [ValidateSet('ServicePack', 'CumulativeUpdate')]
        [string]$Type,
        [object[]]$Component,
        [Parameter(ParameterSetName = 'Number')]
        [int]$ServicePack,
        [Parameter(ParameterSetName = 'Number')]
        [int]$CumulativeUpdate,
        [Parameter(Mandatory, ParameterSetName = 'KB')]
        [ValidateNotNullOrEmpty()]
        [string]$KB,
        [string]$InstanceName,
        [bool]$EnableException = $EnableException,
        [bool]$Continue
    )
    process {

        # check if any type of the update was specified
        if ($PSCmdlet.ParameterSetName -eq 'Number' -and -not ((Test-Bound ServicePack) -or (Test-Bound CumulativeUpdate))) {
            Stop-Function -Message "No update was specified, provide at least one value for either SP/CU"
            return
        }
        $computer = $ComputerName.ComputerName
        $verCount = ($Component | Measure-Object).Count
        $verDesc = ($Component | ForEach-Object { "$($_.Version.NameLevel) ($($_.Version.Build))" }) -join ', '
        Write-Message -Level Debug -Message "Selected $verCount existing SQL Server version(s): $verDesc"

        # Group by version
        $currentVersionGroups = $Component | Group-Object -Property { $_.Version.NameLevel }
        #Check if more than one version is found
        if (($currentVersionGroups | Measure-Object ).Count -gt 1 -and ($CumulativeUpdate -or $ServicePack) -and !$MajorVersion) {
            Stop-Function -Message "Updating multiple different versions of SQL Server to a specific SP/CU is not supported. Please specify a version of SQL Server on $computer that you want to update."
            return
        }
        ## Find the architecture of the computer
        if ($arch = (Get-DbaCmObject -ComputerName $computer -ClassName 'Win32_ComputerSystem').SystemType) {
            if ($arch -eq 'x64-based PC') {
                $arch = 'x64'
            } else {
                $arch = 'x86'
            }
        } else {
            Write-Message -Level Warning -Message "Failed to determine the arch of $computer, using x64 by default"
            $arch = 'x64'
        }
        $targetLevel = ''
        # Launch a setup sequence for each version found
        foreach ($currentGroup in $currentVersionGroups) {
            $currentMajorVersion = "SQL" + $currentGroup.Name
            $currentMajorNumber = $currentGroup.Name

            # Use the earliest version in case specifics are needed
            $currentVersion = $currentGroup.Group | Sort-Object -Property { $_.Version.BuildLevel } | Select-Object -ExpandProperty Version -First 1

            #create output object
            $output = [pscustomobject]@{
                ComputerName  = $ComputerName
                MajorVersion  = $currentMajorNumber
                Build         = $currentVersion.Build
                Architecture  = $arch
                TargetVersion = $null
                TargetLevel   = $null
                KB            = $null
                Successful    = $false
                Restarted     = $false
                InstanceName  = $InstanceName
                Installer     = $null
                ExtractPath   = $null
                Notes         = @()
                ExitCode      = $null
                Log           = $null
            }

            # Find target KB number based on provided SP/CU levels or KB numbers
            if ($CumulativeUpdate -gt 0) {
                #Cumulative update is present - installing CU
                if (Test-Bound -Parameter ServicePack) {
                    #Service pack is present - using it as a reference
                    $targetKB = Get-DbaBuild -MajorVersion $currentMajorNumber -ServicePack $ServicePack -CumulativeUpdate $CumulativeUpdate
                } else {
                    #Service pack not present - using current SP level
                    $targetSP = $currentVersion.SPLevel
                    $targetKB = Get-DbaBuild -MajorVersion $currentMajorNumber -ServicePack $targetSP -CumulativeUpdate $CumulativeUpdate
                }
            } elseif ($ServicePack -gt 0) {
                #Service pack number was passed without CU - installing service pack
                $targetKB = Get-DbaBuild -MajorVersion $currentMajorNumber -ServicePack $ServicePack
            } elseif ($KB) {
                $targetKB = Get-DbaBuild -KB $KB
                if ($targetKB -and $currentMajorNumber -ne $targetKB.NameLevel) {
                    Write-Message -Level Debug -Message "$($targetKB.NameLevel) is not a target Major version $($currentMajorNumber), skipping"
                    continue
                }
            } else {
                #No parameters = latest patch. Find latest SQL Server build and corresponding SP and CU KBs
                $latestCU = Test-DbaBuild -Build $currentVersion.BuildLevel -MaxBehind '0CU'
                if (!$latestCU.Compliant) {
                    #more recent build is found, get KB number depending on what is the current upgrade $Type
                    $targetKB = Get-DbaBuild -Build $latestCU.BuildTarget
                    $targetSP = $targetKB.SPLevel
                    if ($Type -eq 'CumulativeUpdate') {
                        if ($currentVersion.SPLevel -ne $latestCU.SPTarget) {
                            $currentSP = $currentVersion.SPLevel
                            Stop-Function -Message "Current SP version $currentMajorVersion$currentSP is not the latest available. Make sure to upgade to latest SP level before applying latest CU." -Continue
                        }
                        $targetLevel = "$($targetKB.SPLevel)$($targetKB.CULevel)"
                        Write-Message -Level Debug -Message "Found a latest Cumulative Update $targetLevel (KB$($targetKB.KBLevel))"
                    } elseif ($Type -eq 'ServicePack') {
                        $targetKB = Get-DbaBuild -MajorVersion $targetKB.NameLevel -ServicePack $targetSP
                        $targetLevel = $targetKB.SPLevel
                        if ($currentVersion.SPLevel -eq $latestCU.SPTarget) {
                            Write-Message -Message "No need to update $currentMajorVersion to $targetLevel - it's already on the latest SP version" -Level Verbose
                            continue
                        }
                        Write-Message -Level Debug -Message "Found a latest Service Pack $targetLevel (KB$($targetKB.KBLevel))"
                    }
                } else {
                    Write-Message -Message "$($currentVersion.Build) on computer [$($computer)] is already the latest available." -Level Warning
                    continue
                }
            }
            if ($targetKB.KBLevel) {
                if ($targetKB.MatchType -ne 'Exact') {
                    Stop-Function -Message "Couldn't find an exact build match with specified parameters while updating $currentMajorVersion" -Continue
                }
                $output.TargetVersion = $targetKB
                $targetLevel = "$($targetKB.SPLevel)$($targetKB.CULevel)"
                $targetKBLevel = $targetKB.KBLevel | Select-Object -First 1
                Write-Message -Level Verbose -Message "Found applicable upgrade for SQL$($targetKB.NameLevel) to $targetLevel (KB$($targetKBLevel))"
                $output.KB = $targetKBLevel
            } else {
                $msg = "Could not find a KB$KB reference for $currentMajorVersion SP $ServicePack CU $CumulativeUpdate"
                $output.Notes += $msg
                $output
                Stop-Function -Message $msg -Continue
            }

            # Compare versions - whether to proceed with the installation
            $needsUpgrade = $false
            foreach ($currentComponent in $currentGroup.Group) {
                $groupVersion = $currentComponent.Version
                #target version is less than requested
                if ($groupVersion.BuildLevel -lt $targetKB.BuildLevel) {
                    $needsUpgrade = $true
                }
                #target version is the same but installation has failed last time
                elseif ($groupVersion.BuildLevel -eq $targetKB.BuildLevel -and $Continue -and $currentComponent.Resume) {
                    $needsUpgrade = $true
                }
            }
            if (!$needsUpgrade) {
                Write-Message -Message "Current $currentMajorVersion version $($currentVersion.BuildLevel) on computer [$($computer)] matches or already higher than target version $($targetKB.BuildLevel)" -Level Verbose
                continue
            }

            $output.TargetLevel = $targetLevel
            $output.Successful = $true
            #Return the object for further processing
            $output
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUQjMJUCOD1GJj4qoGwePaYhRC
# aiSgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFC5Asv9viLbMalE3CL0DM83G8nXoMA0GCSqGSIb3DQEBAQUABIIBAIZdJ8KC
# cVzMIL2E8Hbhnyb3QBEU3dkz3+ICwUiHPwENck1sS3rPMv+sWMeKtKK5kqP3yc8V
# uTBk0AWXc+NgpfpkJK2Z2ftM8iTsDtnlrzyr7Z2m1yVofZctE84acBiCNPVoU0oP
# cK2yfgyg9GDm7heEh3q7+bgNG4IwMYgH1+qzA1+aLSsw20OEF8xL8w4Rp8AeLGyd
# G9j1zfHSmNjFW17whUvYohy10SA48IYxsieBWihCLANvUkL/XwR36j/XkkmKtlJQ
# bY4+7rgU97sl0XhhQTFwo/BuEjfn77pIKJtV0durGE48JKTNKt05NqF57uNOFCRg
# 0FR8fG4qbp2kRhyhggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDgwNTEwMDUxOVowLwYJKoZIhvcNAQkEMSIEIAWNrGZOo4iEsuDoz7VK0oqewLpP
# 8okLNdPqdDNtR92GMA0GCSqGSIb3DQEBAQUABIIBAEjM5jcy4biMSTKvkhi85jkJ
# jwvCEedwxQaaVIyGFwE2qdtpVw2Ngse3LieDFw9c7GuK/X3ENZG0uf8uLPrFK2WB
# T1V2uAY+WaHz1h5N6jcTJQmWzGv3CVCblmNLXCL/YUGPjYCQ7mgL9T2xvVOYOLui
# h9jsEDTfrApqSLLLEtkKGtT1pUlZELuLFYBYkF6qoG02mM/t12ZMl0I0aC+foW3g
# Z7wv3NAefbr6J2J7diEyZAfBGle4/+6pKxLMr3K0BpGYLK9fYaPK7bx4SnyytKxR
# BInl+BTZnLDWqPMYuIX+EBZM/7s+mMSl+VX8bNU+4V8cyQlpHs2Zx5LgvMPBppo=
# SIG # End signature block
