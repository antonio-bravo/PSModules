function Get-DbaMaintenanceSolutionLog {
    <#
    .SYNOPSIS
        Reads the log files generated by the IndexOptimize Agent Job from Ola Hallengren's MaintenanceSolution.

    .DESCRIPTION
        Ola wrote a .sql script to get the content from the commandLog table. However, if LogToTable='N', there will be no logging in that table. This function reads the text files that are written in the SQL Instance's Log directory.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER LogType
        Accepts 'IndexOptimize', 'DatabaseBackup', 'DatabaseIntegrityCheck'. ATM only IndexOptimize parsing is available

    .PARAMETER Since
        Consider only files generated since this date

    .PARAMETER Path
        Where to search for log files. By default it's the SQL instance error log path path

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Community, OlaHallengren
        Author: Klaas Vandenberghe (@powerdbaklaas) | Simone Bizzotto ( @niphlod )

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

        https://ola.hallengren.com

    .LINK
        https://dbatools.io/Get-DbaMaintenanceSolutionLog

    .EXAMPLE
        PS C:\> Get-DbaMaintenanceSolutionLog -SqlInstance sqlserver2014a

        Gets the outcome of the IndexOptimize job on sql instance sqlserver2014a.

    .EXAMPLE
        PS C:\> Get-DbaMaintenanceSolutionLog -SqlInstance sqlserver2014a -SqlCredential $credential

        Gets the outcome of the IndexOptimize job on sqlserver2014a, using SQL Authentication.

    .EXAMPLE
        PS C:\> 'sqlserver2014a', 'sqlserver2020test' | Get-DbaMaintenanceSolutionLog

        Gets the outcome of the IndexOptimize job on sqlserver2014a and sqlserver2020test.

    .EXAMPLE
        PS C:\> Get-DbaMaintenanceSolutionLog -SqlInstance sqlserver2014a -Path 'D:\logs\maintenancesolution\'

        Gets the outcome of the IndexOptimize job on sqlserver2014a, reading the log files in their custom location.

    .EXAMPLE
        PS C:\> Get-DbaMaintenanceSolutionLog -SqlInstance sqlserver2014a -Since '2017-07-18'

        Gets the outcome of the IndexOptimize job on sqlserver2014a, starting from july 18, 2017.

    .EXAMPLE
        PS C:\> Get-DbaMaintenanceSolutionLog -SqlInstance sqlserver2014a -LogType IndexOptimize

        Gets the outcome of the IndexOptimize job on sqlserver2014a, the other options are not yet available! sorry

    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification = "Internal functions are ignored")]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [ValidateSet('IndexOptimize', 'DatabaseBackup', 'DatabaseIntegrityCheck')]
        [string[]]$LogType = 'IndexOptimize',
        [datetime]$Since,
        [string]$Path,
        [switch]$EnableException
    )
    begin {
        function process-block ($block) {
            $fresh = @{
                'ObjectType'     = $null
                'IndexType'      = $null
                'ImageText'      = $null
                'NewLOB'         = $null
                'FileStream'     = $null
                'ColumnStore'    = $null
                'AllowPageLocks' = $null
                'PageCount'      = $null
                'Fragmentation'  = $null
                'Error'          = $null
            }
            foreach ($l in $block) {
                $splitted = $l -split ': ', 2
                if (($splitted.Length -ne 2) -or ($splitted[0].length -gt 20)) {
                    if ($null -eq $fresh['Error']) {
                        $fresh['Error'] = New-Object System.Collections.ArrayList
                    }
                    $null = $fresh['Error'].Add($l)
                    continue
                }
                $k = $splitted[0]
                $v = $splitted[1]
                if ($k -eq 'Date and Time') {
                    # this is the end date, we already parsed the start date of the block
                    if ($fresh.ContainsKey($k)) {
                        continue
                    }
                }
                $fresh[$k] = $v
            }
            if ($fresh.ContainsKey('Command')) {
                if ($fresh['Command'] -match '(SET LOCK_TIMEOUT (?<timeout>\d+); )?ALTER INDEX \[(?<index>[^\]]+)\] ON \[(?<database>[^\]]+)\]\.\[(?<schema>[^]]+)\]\.\[(?<table>[^\]]+)\] (?<action>[^\ ]+)( PARTITION = (?<partition>\d+))? WITH \((?<options>[^\)]+)') {
                    $fresh['Index'] = $Matches.index
                    $fresh['Statistics'] = $null
                    $fresh['Schema'] = $Matches.Schema
                    $fresh['Table'] = $Matches.Table
                    $fresh['Action'] = $Matches.action
                    $fresh['Options'] = $Matches.options
                    $fresh['Timeout'] = $Matches.timeout
                    $fresh['Partition'] = $Matches.partition
                } elseif ($fresh['Command'] -match '(SET LOCK_TIMEOUT (?<timeout>\d+); )?UPDATE STATISTICS \[(?<database>[^\]]+)\]\.\[(?<schema>[^]]+)\]\.\[(?<table>[^\]]+)\] \[(?<stat>[^\]]+)\]') {
                    $fresh['Index'] = $null
                    $fresh['Statistics'] = $Matches.stat
                    $fresh['Schema'] = $Matches.Schema
                    $fresh['Table'] = $Matches.Table
                    $fresh['Action'] = $null
                    $fresh['Options'] = $null
                    $fresh['Timeout'] = $Matches.timeout
                    $fresh['Partition'] = $null
                }
            }
            if ($fresh.ContainsKey('Comment')) {
                $commentParts = $fresh['Comment'] -split ', '
                foreach ($part in $commentParts) {
                    $indKey, $indValue = $part -split ': ', 2
                    if ($fresh.ContainsKey($indKey)) {
                        $fresh[$indKey] = $indValue
                    }
                }
            }
            if ($null -ne $fresh['Error']) {
                $fresh['Error'] = $fresh['Error'] -join "`n"
            }

            return $fresh
        }
    }
    process {
        foreach ($instance in $SqlInstance) {
            $logDir = $logFiles = $null
            $computername = $instance.ComputerName

            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            if ($LogType -ne 'IndexOptimize') {
                Write-Message -Level Warning -Message "Parsing $LogType is not supported at the moment"
                Continue
            }
            if (!$instance.IsLocalHost -and $server.HostPlatform -ne "Windows") {
                Write-Message -Level Warning -Message "The target instance is not Windows so logs cannot be fetched remotely"
                Continue
            }
            if ($Path) {
                $logDir = Join-AdminUnc -Servername $server.ComputerName -Filepath $Path
            } else {
                $logDir = Join-AdminUnc -Servername $server.ComputerName -Filepath $server.errorlogpath # -replace '^(.):', "\\$computername\`$1$"
            }
            if (!$logDir) {
                Write-Message -Level Warning -Message "No log directory returned from $instance"
                Continue
            }

            Write-Message -Level Verbose -Message "Log directory on $computername is $logDir"
            if (! (Test-Path $logDir)) {
                Write-Message -Level Warning -Message "Directory $logDir is not accessible"
                continue
            }
            $logFiles = [System.IO.Directory]::EnumerateFiles("$logDir", "IndexOptimize_*.txt")
            if ($Since) {
                $filteredLogs = @()
                foreach ($l in $logFiles) {
                    $base = $($l.Substring($l.Length - 15, 15))
                    try {
                        $dateFile = [DateTime]::ParseExact($base, 'yyyyMMdd_HHmmss', $null)
                    } catch {
                        $dateFile = Get-ItemProperty -Path $l | Select-Object -ExpandProperty CreationTime
                    }
                    if ($dateFile -gt $since) {
                        $filteredLogs += $l
                    }
                }
                $logFiles = $filteredLogs
            }
            if (! $logFiles.count -ge 1) {
                Write-Message -Level Warning -Message "No log files returned from $computername"
                Continue
            }
            $instanceInfo = @{ }
            $instanceInfo['ComputerName'] = $server.ComputerName
            $instanceInfo['InstanceName'] = $server.ServiceName
            $instanceInfo['SqlInstance'] = $server.Name

            foreach ($File in $logFiles) {
                Write-Message -Level Verbose -Message "Reading $file"
                $text = New-Object System.IO.StreamReader -ArgumentList "$File"
                $block = New-Object System.Collections.ArrayList
                $remember = @{ }
                while ($line = $text.ReadLine()) {

                    $real = $line.Trim()
                    if ($real.Length -eq 0) {
                        $processed = process-block $block
                        if ('Procedure' -in $processed.Keys) {
                            $block = New-Object System.Collections.ArrayList
                            continue
                        }
                        if ('Database' -in $processed.Keys) {
                            Write-Message -Level Verbose -Message "Index and Stats Optimizations on Database $($processed.Database) on $computername"
                            $processed.Remove('Is accessible')
                            $processed.Remove('User access')
                            $processed.Remove('Date and time')
                            $processed.Remove('Standby')
                            $processed.Remove('Recovery Model')
                            $processed.Remove('Updateability')
                            $processed['Database'] = $processed['Database'].Trim('[]')
                            $remember = $processed.Clone()
                        } else {
                            foreach ($k in $processed.Keys) {
                                $remember[$k] = $processed[$k]
                            }
                            $remember.Remove('Command')
                            $remember['StartTime'] = [dbadatetime]([DateTime]::ParseExact($remember['Date and time'] , "yyyy-MM-dd HH:mm:ss", $null))
                            $remember.Remove('Date and time')
                            $remember['Duration'] = ($remember['Duration'] -as [timespan])
                            [pscustomobject]$remember
                        }
                        $block = New-Object System.Collections.ArrayList
                    } else {
                        $null = $block.Add($real)
                    }
                }
                $text.close()
            }
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8i+5tZvsaJo07AeDgM5m/GD0
# /HygghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFOlJtC20F1Swum3KCcEzot3SVa67MA0GCSqGSIb3DQEBAQUABIIBABIhKJ+e
# pTiwcbGtDDySkzJ4Xq02cRpBFZxeUCJhGckIqHv51HtkOAy/ar1elby61hNKHaIu
# OnhfsmEIMJfbGWYENXTAADPmmdziHge+BI8MJ6W58kzCVrB2sl9xwUJD/c5NhtqV
# QJtEWVbsNIHNxGIXDjYSTpBaXshy2quAhJ9JqCniQhXCR6QN3Bm9Qq1hg0mcr2p6
# E8wXaFp3+iS+fv0nek667CvPuP7z3/ai5Bk9jokgOPBqm0utcRHi+L/d1IJe4E3A
# OVeDOWRtDPbPEV2roMkZ3CnIM4nQdjk54++fpQGl6IAWwCqtLZ1KtAuF3YMLYeym
# VcJYuE1+9FUDtk2hggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDkxODEyNDcyMlowLwYJKoZIhvcNAQkEMSIEIJ4XYALsoBc67O4aZLyMRDIKxDd0
# hWJjmtQK8gntarjKMA0GCSqGSIb3DQEBAQUABIIBAFOMN83C/XMubaUSrLNkEl7v
# 3HKrVnDaJR0u9t+0qXheEzyHJDlrwBXZGtL20G6GM/TBYEHfEyiPHdcg5xSkHmYG
# EIhOzNiEJ+t/EvOiRGA5J51zuDK3dHx0Ly4a8RgIK+ODuc4MG2i9JUuh5pgOHFif
# s0rqepLahndjzTW3A/w2pi4JdbJESJ33XdYv6zarKz8K9ySwejDWrcZyl7Iwi8wu
# thnRpPh7DdF1VuhdBKmwrBJhS+xzIjf3ShrwPigMa5qw6u8+SDjuoE3DtKeOaeSh
# LCD7t03APtzx2V+UFxA555+hVTZrLPJqROTOvxjAiVpSa82pLi5u8zXoxT0vupw=
# SIG # End signature block