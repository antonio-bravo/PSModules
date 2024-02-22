function Set-DbaDbQueryStoreOption {
    <#
    .SYNOPSIS
        Configure Query Store settings for a specific or multiple databases.

    .DESCRIPTION
        Configure Query Store settings for a specific or multiple databases.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        SqlLogin to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance..

    .PARAMETER Database
        The database(s) to process - this list is auto-populated from the server. If unspecified, all databases will be processed.

    .PARAMETER ExcludeDatabase
        The database(s) to exclude - this list is auto-populated from the server

    .PARAMETER AllDatabases
        Run command against all user databases

    .PARAMETER State
        Set the state of the Query Store. Valid options are "ReadWrite", "ReadOnly" and "Off".

    .PARAMETER FlushInterval
        Set the flush to disk interval of the Query Store in seconds.

    .PARAMETER CollectionInterval
        Set the runtime statistics collection interval of the Query Store in minutes.

    .PARAMETER MaxSize
        Set the maximum size of the Query Store in MB.

    .PARAMETER CaptureMode
        Set the query capture mode of the Query Store. Valid options are "Auto" and "All".

    .PARAMETER CleanupMode
        Set the query cleanup mode policy. Valid options are "Auto" and "Off".

    .PARAMETER StaleQueryThreshold
        Set the stale query threshold in days.

    .PARAMETER MaxPlansPerQuery
        Set the max plans per query captured and kept.

    .PARAMETER WaitStatsCaptureMode
        Set wait stats capture on or off.

    .PARAMETER CustomCapturePolicyExecutionCount
        Set the custom capture policy execution count. Only available in SQL Server 2019 and above.

    .PARAMETER CustomCapturePolicyTotalCompileCPUTimeMS
        Set the custom capture policy total compile CPU time. Only available in SQL Server 2019 and above.

    .PARAMETER CustomCapturePolicyTotalExecutionCPUTimeMS
        Set the custom capture policy total execution CPU time. Only available in SQL Server 2019 and above.

    .PARAMETER CustomCapturePolicyStaleThresholdHours
        Set the custom capture policy stale threshold. Only available in SQL Server 2019 and above.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run

    .PARAMETER Confirm
        Prompts for confirmation of every step. For example:

        Are you sure you want to perform this action?
        Performing the operation "Changing Desired State" on target "pubs on SQL2016\VNEXT".
        [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: QueryStore
        Author: Enrico van de Laar (@evdlaar) | Tracy Boggiano (@TracyBoggiano)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Set-DbaDbQueryStoreOption

    .EXAMPLE
        PS C:\> Set-DbaDbQueryStoreOption -SqlInstance ServerA\SQL -State ReadWrite -FlushInterval 600 -CollectionInterval 10 -MaxSize 100 -CaptureMode All -CleanupMode Auto -StaleQueryThreshold 100 -AllDatabases

        Configure the Query Store settings for all user databases in the ServerA\SQL Instance.

    .EXAMPLE
        PS C:\> Set-DbaDbQueryStoreOption -SqlInstance ServerA\SQL -FlushInterval 600

        Only configure the FlushInterval setting for all Query Store databases in the ServerA\SQL Instance.

    .EXAMPLE
        PS C:\> Set-DbaDbQueryStoreOption -SqlInstance ServerA\SQL -Database AdventureWorks -State ReadWrite -FlushInterval 600 -CollectionInterval 10 -MaxSize 100 -CaptureMode all -CleanupMode Auto -StaleQueryThreshold 100

        Configure the Query Store settings for the AdventureWorks database in the ServerA\SQL Instance.

    .EXAMPLE
        PS C:\> Set-DbaDbQueryStoreOption -SqlInstance ServerA\SQL -Exclude AdventureWorks -State ReadWrite -FlushInterval 600 -CollectionInterval 10 -MaxSize 100 -CaptureMode all -CleanupMode Auto -StaleQueryThreshold 100

        Configure the Query Store settings for all user databases except the AdventureWorks database in the ServerA\SQL Instance.

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]
        $SqlCredential,
        [object[]]$Database,
        [object[]]$ExcludeDatabase,
        [switch]$AllDatabases,
        [ValidateSet('ReadWrite', 'ReadOnly', 'Off')]
        [string[]]$State,
        [int64]$FlushInterval,
        [int64]$CollectionInterval,
        [int64]$MaxSize,
        [ValidateSet('Auto', 'All', 'None', 'Custom')]
        [string[]]$CaptureMode,
        [ValidateSet('Auto', 'Off')]
        [string[]]$CleanupMode,
        [int64]$StaleQueryThreshold,
        [int64]$MaxPlansPerQuery,
        [ValidateSet('On', 'Off')]
        [string[]]$WaitStatsCaptureMode,
        [int64]$CustomCapturePolicyExecutionCount,
        [int64]$CustomCapturePolicyTotalCompileCPUTimeMS,
        [int64]$CustomCapturePolicyTotalExecutionCPUTimeMS,
        [int64]$CustomCapturePolicyStaleThresholdHours,
        [switch]$EnableException
    )
    begin {
        $ExcludeDatabase += 'master', 'tempdb', "model"
    }

    process {
        if (-not $Database -and -not $ExcludeDatabase -and -not $AllDatabases) {
            Stop-Function -Message "You must specify a database(s) to execute against using either -Database, -ExcludeDatabase or -AllDatabases"
            return
        }

        if (-not $State -and -not $FlushInterval -and -not $CollectionInterval -and -not $MaxSize -and -not $CaptureMode -and -not $CleanupMode -and -not $StaleQueryThreshold -and -not $MaxPlansPerQuery -and -not $WaitStatsCaptureMode -and -not $CustomCapturePolicyExecutionCount -and -not $CustomCapturePolicyTotalCompileCPUTimeMS -and -not $CustomCapturePolicyTotalExecutionCPUTimeMS -and -not $CustomCapturePolicyStaleThresholdHours) {
            Stop-Function -Message "You must specify something to change."
            return
        }

        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 13
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ($CaptureMode -contains "Custom" -and $server.VersionMajor -lt 15) {
                Stop-Function -Message "Custom capture mode can onlly be set in SQL Server 2019 and above" -Continue
            }

            if (($CustomCapturePolicyExecutionCount -or $CustomCapturePolicyTotalCompileCPUTimeMS -or $CustomCapturePolicyTotalExecutionCPUTimeMS -or $CustomCapturePolicyStaleThresholdHours) -and $server.VersionMajor -lt 15) {
                Write-Message -Level Warning -Message "Custom Capture Policies can only be set in SQL Server 2019 and above. These options will be skipped for $instance"
            }

            # We have to exclude all the system databases since they cannot have the Query Store feature enabled
            $dbs = Get-DbaDatabase -SqlInstance $server -ExcludeDatabase $ExcludeDatabase -Database $Database | Where-Object IsAccessible

            foreach ($db in $dbs) {
                Write-Message -Level Verbose -Message "Processing $($db.name) on $instance"

                if ($db.IsAccessible -eq $false) {
                    Write-Message -Level Warning -Message "The database $db on server $instance is not accessible. Skipping database."
                    continue
                }

                if ($State) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing DesiredState to $state")) {
                        $db.QueryStoreOptions.DesiredState = $State
                        $db.QueryStoreOptions.Alter()
                        $db.QueryStoreOptions.Refresh()
                    }
                }

                if ($db.QueryStoreOptions.DesiredState -eq "Off" -and (Test-Bound -Parameter State -Not)) {
                    Write-Message -Level Warning -Message "State is set to Off; cannot change values. Please update State to ReadOnly or ReadWrite."
                    continue
                }

                if ($FlushInterval) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing DataFlushIntervalInSeconds to $FlushInterval")) {
                        $db.QueryStoreOptions.DataFlushIntervalInSeconds = $FlushInterval
                    }
                }

                if ($CollectionInterval) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing StatisticsCollectionIntervalInMinutes to $CollectionInterval")) {
                        $db.QueryStoreOptions.StatisticsCollectionIntervalInMinutes = $CollectionInterval
                    }
                }

                if ($MaxSize) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing MaxStorageSizeInMB to $MaxSize")) {
                        $db.QueryStoreOptions.MaxStorageSizeInMB = $MaxSize
                    }
                }

                if ($CaptureMode) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing QueryCaptureMode to $CaptureMode")) {
                        $db.QueryStoreOptions.QueryCaptureMode = $CaptureMode
                    }
                }

                if ($CleanupMode) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing SizeBasedCleanupMode to $CleanupMode")) {
                        $db.QueryStoreOptions.SizeBasedCleanupMode = $CleanupMode
                    }
                }

                if ($StaleQueryThreshold) {
                    if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing StaleQueryThresholdInDays to $StaleQueryThreshold")) {
                        $db.QueryStoreOptions.StaleQueryThresholdInDays = $StaleQueryThreshold
                    }
                }

                $query = ""

                if ($server.VersionMajor -ge 14) {
                    if ($MaxPlansPerQuery) {
                        if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing MaxPlansPerQuery to $($MaxPlansPerQuery)")) {
                            $query += "ALTER DATABASE $db SET QUERY_STORE = ON (MAX_PLANS_PER_QUERY = $($MaxPlansPerQuery)); "
                        }
                    }

                    if ($WaitStatsCaptureMode) {
                        if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing WaitStatsCaptureMode to $($WaitStatsCaptureMode)")) {
                            if ($WaitStatsCaptureMode -eq "ON" -or $WaitStatsCaptureMode -eq "OFF") {
                                $query += "ALTER DATABASE $db SET QUERY_STORE = ON (WAIT_STATS_CAPTURE_MODE = $($WaitStatsCaptureMode)); "
                            }
                        }
                    }
                }

                if ($server.VersionMajor -ge 15) {
                    if ($db.QueryStoreOptions.QueryCaptureMode -eq "CUSTOM") {
                        if ($CustomCapturePolicyStaleThresholdHours) {
                            if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing CustomCapturePolicyStaleThresholdHours to $($CustomCapturePolicyStaleThresholdHours)")) {
                                $query += "ALTER DATABASE $db SET QUERY_STORE = ON ( QUERY_CAPTURE_POLICY = ( STALE_CAPTURE_POLICY_THRESHOLD = $($CustomCapturePolicyStaleThresholdHours))); "
                            }
                        }

                        if ($CustomCapturePolicyExecutionCount) {
                            if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing CustomCapturePolicyExecutionCount to $($CustomCapturePolicyExecutionCount)")) {
                                $query += "ALTER DATABASE $db SET QUERY_STORE = ON (QUERY_CAPTURE_POLICY = (EXECUTION_COUNT = $($CustomCapturePolicyExecutionCount))); "
                            }
                        }
                        if ($CustomCapturePolicyTotalCompileCPUTimeMS) {
                            if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing CustomCapturePolicyTotalCompileCPUTimeMS to $($CustomCapturePolicyTotalCompileCPUTimeMS)")) {
                                $query += "ALTER DATABASE $db SET QUERY_STORE = ON (QUERY_CAPTURE_POLICY = (TOTAL_COMPILE_CPU_TIME_MS = $($CustomCapturePolicyTotalCompileCPUTimeMS))); "
                            }
                        }

                        if ($CustomCapturePolicyTotalExecutionCPUTimeMS) {
                            if ($Pscmdlet.ShouldProcess("$db on $instance", "Changing CustomCapturePolicyTotalExecutionCPUTimeMS to $($CustomCapturePolicyTotalExecutionCPUTimeMS)")) {
                                $query += "ALTER DATABASE $db SET QUERY_STORE = ON (QUERY_CAPTURE_POLICY = (TOTAL_EXECUTION_CPU_TIME_MS = $($CustomCapturePolicyTotalExecutionCPUTimeMS))); "
                            }
                        }
                    }
                }

                # Alter the Query Store Configuration
                if ($Pscmdlet.ShouldProcess("$db on $instance", "Altering Query Store configuration on database")) {
                    try {
                        $db.QueryStoreOptions.Alter()
                        $db.Alter()
                        $db.Refresh()

                        if ($query -ne "") {
                            $db.Query($query, $db.Name)
                        }
                    } catch {
                        Stop-Function -Message "Could not modify configuration." -Category InvalidOperation -InnerErrorRecord $_ -Target $db -Continue
                    }
                }

                if ($Pscmdlet.ShouldProcess("$db on $instance", "Getting results from Get-DbaDbQueryStoreOption")) {
                    Get-DbaDbQueryStoreOption -SqlInstance $server -Database $db.name -Verbose:$false
                }
            }
        }
    }
}


# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCnVTTgrPaVix4D
# kWU5b37RwSbMRRSjp5I0d2WUbdW2yKCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
# Y1+/3q4SBOdtMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcN
# MjAwNTEyMDAwMDAwWhcNMjMwNjA4MTIwMDAwWjBXMQswCQYDVQQGEwJVUzERMA8G
# A1UECBMIVmlyZ2luaWExDzANBgNVBAcTBlZpZW5uYTERMA8GA1UEChMIZGJhdG9v
# bHMxETAPBgNVBAMTCGRiYXRvb2xzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAvL9je6vjv74IAbaY5rXqHxaNeNJO9yV0ObDg+kC844Io2vrHKGD8U5hU
# iJp6rY32RVprnAFrA4jFVa6P+sho7F5iSVAO6A+QZTHQCn7oquOefGATo43NAadz
# W2OWRro3QprMPZah0QFYpej9WaQL9w/08lVaugIw7CWPsa0S/YjHPGKQ+bYgI/kr
# EUrk+asD7lvNwckR6pGieWAyf0fNmSoevQBTV6Cd8QiUfj+/qWvLW3UoEX9ucOGX
# 2D8vSJxL7JyEVWTHg447hr6q9PzGq+91CO/c9DWFvNMjf+1c5a71fEZ54h1mNom/
# XoWZYoKeWhKnVdv1xVT1eEimibPEfQIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAU
# WsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYEFPDAoPu2A4BDTvsJ193ferHL
# 454iMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8E
# cDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVk
# LWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTIt
# YXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggr
# BgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEw
# gYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAj835cJUMH9Y2pBKspjznNJwcYmOxeBcH
# Ji+yK0y4bm+j44OGWH4gu/QJM+WjZajvkydJKoJZH5zrHI3ykM8w8HGbYS1WZfN4
# oMwi51jKPGZPw9neGS2PXrBcKjzb7rlQ6x74Iex+gyf8z1ZuRDitLJY09FEOh0BM
# LaLh+UvJ66ghmfIyjP/g3iZZvqwgBhn+01fObqrAJ+SagxJ/21xNQJchtUOWIlxR
# kuUn9KkuDYrMO70a2ekHODcAbcuHAGI8wzw4saK1iPPhVTlFijHS+7VfIt/d/18p
# MLHHArLQQqe1Z0mTfuL4M4xCUKpebkH8rI3Fva62/6osaXLD0ymERzCCBTAwggQY
# oAMCAQICEAQJGBtf1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTEzMTAyMjEyMDAwMFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEx
# MC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsx
# SRnP0PtFmbE620T1f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawO
# eSg6funRZ9PG+yknx9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJ
# RdQtoaPpiCwgla4cSocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEc
# z+ryCuRXu0q16XTmK/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whk
# PlKWwfIPEvTFjg/BougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8l
# k9ECAwEAAaOCAc0wggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARI
# MEYwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdp
# Y2VydC5jb20vQ1BTMAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg
# +S32ZXUOWDAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG
# 9w0BAQsFAAOCAQEAPuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/E
# r4v97yrfIFU3sOH20ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3
# nEZOXP+QsRsHDpEV+7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpo
# aK+bp1wgXNlxsQyPu6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW
# 6Fkd6fp0ZGuy62ZD2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ
# 92JuoVP6EpQYhS6SkepobEQysmah5xikmmRR7zCCBY0wggR1oAMCAQICEA6bGI75
# 0C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAw
# MFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuE
# DcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNw
# wrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs0
# 6wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e
# 5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtV
# gkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85
# tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+S
# kjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1Yxw
# LEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzl
# DlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFr
# b7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATow
# ggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiu
# HA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQE
# AwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2
# hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/
# Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNK
# ei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHr
# lnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4
# oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5A
# Y8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNN
# n3O3AamfV6peKOK5lDCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbAMIIEqKADAgECAhAMTWlyS5T6PCpKPSkHgD1aMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjIwOTIxMDAwMDAwWhcNMzMxMTIxMjM1OTU5WjBGMQswCQYDVQQGEwJV
# UzERMA8GA1UEChMIRGlnaUNlcnQxJDAiBgNVBAMTG0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDIyIC0gMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAM/spSY6
# xqnya7uNwQ2a26HoFIV0MxomrNAcVR4eNm28klUMYfSdCXc9FZYIL2tkpP0GgxbX
# kZI4HDEClvtysZc6Va8z7GGK6aYo25BjXL2JU+A6LYyHQq4mpOS7eHi5ehbhVsbA
# umRTuyoW51BIu4hpDIjG8b7gL307scpTjUCDHufLckkoHkyAHoVW54Xt8mG8qjoH
# ffarbuVm3eJc9S/tjdRNlYRo44DLannR0hCRRinrPibytIzNTLlmyLuqUDgN5YyU
# XRlav/V7QG5vFqianJVHhoV5PgxeZowaCiS+nKrSnLb3T254xCg/oxwPUAY3ugjZ
# Naa1Htp4WB056PhMkRCWfk3h3cKtpX74LRsf7CtGGKMZ9jn39cFPcS6JAxGiS7uY
# v/pP5Hs27wZE5FX/NurlfDHn88JSxOYWe1p+pSVz28BqmSEtY+VZ9U0vkB8nt9Kr
# FOU4ZodRCGv7U0M50GT6Vs/g9ArmFG1keLuY/ZTDcyHzL8IuINeBrNPxB9Thvdld
# S24xlCmL5kGkZZTAWOXlLimQprdhZPrZIGwYUWC6poEPCSVT8b876asHDmoHOWIZ
# ydaFfxPZjXnPYsXs4Xu5zGcTB5rBeO3GiMiwbjJ5xwtZg43G7vUsfHuOy2SJ8bHE
# uOdTXl9V0n0ZKVkDTvpd6kVzHIR+187i1Dp3AgMBAAGjggGLMIIBhzAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAg
# BgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZ
# bU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFGKK3tBh/I8xFO2XC809KpQU31Kc
# MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAG
# CCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2Vy
# dC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAFWqKhrzRvN4Vzcw/HXjT9aFI/H8+ZU5myXm93KK
# mMN31GT8Ffs2wklRLHiIY1UJRjkA/GnUypsp+6M/wMkAmxMdsJiJ3HjyzXyFzVOd
# r2LiYWajFCpFh0qYQitQ/Bu1nggwCfrkLdcJiXn5CeaIzn0buGqim8FTYAnoo7id
# 160fHLjsmEHw9g6A++T/350Qp+sAul9Kjxo6UrTqvwlJFTU2WZoPVNKyG39+Xgmt
# dlSKdG3K0gVnK3br/5iyJpU4GYhEFOUKWaJr5yI+RCHSPxzAm+18SLLYkgyRTzxm
# lK9dAlPrnuKe5NMfhgFknADC6Vp0dQ094XmIvxwBl8kZI4DXNlpflhaxYwzGRkA7
# zl011Fk+Q5oYrsPJy8P7mxNfarXH4PMFw1nfJ2Ir3kHJU7n/NBBn9iYymHv+XEKU
# gZSCnawKi8ZLFUrTmJBFYDOA4CPe+AOk9kVH5c64A0JH6EE2cXet/aLol3ROLtoe
# HYxayB6a1cLwxiKoT5u92ByaUcQvmvZfpyeXupYuhVfAYOd4Vn9q78KVmksRAsiC
# nMkaBXy6cbVOepls9Oie1FqYyJ+/jbsYXEP10Cro4mLueATbvdH7WwqocH7wl4R4
# 4wgDXUcsY6glOJcB0j862uXl9uab3H4szP8XTE0AotjWAQ64i+7m4HJViSwnGWH2
# dwGMMYIFXTCCBVkCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQAwW7hiGwoWNf
# v96uEgTnbTANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCg6SpdadM/OeYf9H0bZgsME6hN
# RgqVk02Iou9iF76iuTANBgkqhkiG9w0BAQEFAASCAQBpyyJL/4mRmMc64c0j2iIz
# y3Ze6UZQoY/v8kc5/GoBbt5VqyJH9UXxSG1gnAdBUO9gZv2I84PJZugC3ysqRX4z
# 1/O6wtVF9bgn/vygb+opydMqJQ1CvVR4QKtFbg9POsd73ncs2Cx5uL8lAiTEGPoe
# fFFUt2gHk9t1dhiJDMczx3emQkPQEWTZOhJsRTpsn1Nx586Z5UIbfuAJX4b0bDb5
# ySRdTgMKP8IF1xXpv6LKSVHP+jcxk2UEb/uD3J4o+FKSipWAwxh9xTP8kpr7RroT
# 5FKZXOT3wl3BJdnehAimpaVRcBSdR+ipxh5ak7CiGKkOY35WyYKuYm2YOw6cQTuo
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDczNVowLwYJKoZIhvcNAQkEMSIE
# IBAToQBCW0ASfY99YI0hE+57+tAbXOQYKLDPfOKjsFjXMA0GCSqGSIb3DQEBAQUA
# BIICAME32WC5HNFwbqmETI1kaOxWbx3NYsq3c5neXtpN/se+mPKcjTi+jkyCijhM
# Me7isoS9E6BYN6c9+INhfi4PAnOt2pXkgPrSpB0y5m7Dx1uvkGVS+wP9tQC2OmA5
# Cv8ceG5BVfRW93MXFnys8t8JkoHtn+LtDafYGpripr6j3LFbBHNrD3cOXy+U16zg
# otti0r1fCG+txMAbI/t9zrY+WXgAakfKjyc+w/OP6XQ3M+FIlNTpE/OW/DkujXCl
# 77OcuBzADK5/pqtHdu7XpkYR8SqindKhQqvQPGpTT7rxUw1oFkkJq2N8Ntc7VK35
# okXu/Cc0LblXvZZlzySEDEm1v7xzknmEw0yjYr2P2C+qplDNQ8sOUVRqra+pI51H
# fbXzkVIUwGc7U//E07es6c12DECN3szuEyr3eIVPDexJgWr5kH7c/iyHgqmyn3wi
# TwfWf1uflBqq3Lpj7yY8hvUoVlaUv8xzXgMAR80fMJWfibDDdOR07ayWapak6lfg
# 9xd9kdTLB8h5guiQdP94hZDygP+5JZHthe2jTs2738ensD1r0MsG/QAifFBSaUpU
# gdsBMsKkX40mY8UNhx1XlR1RWbWm1QSbCllwAt1+VJg4bEf/7wu6ZzyD8Bx0Emy4
# fXyzUY1N0/n5+Dlnle8e+QgXJDEbgmL9Ec69UWV5Ie55JWMC
# SIG # End signature block
