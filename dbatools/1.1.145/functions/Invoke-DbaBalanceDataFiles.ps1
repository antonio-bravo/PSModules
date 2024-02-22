function Invoke-DbaBalanceDataFiles {
    <#
    .SYNOPSIS
        Re-balance data between data files

    .DESCRIPTION
        When you have a large database with a single data file and add another file, SQL Server will only use the new file until it's about the same size.
        You may want to balance the data between all the data files.

        The function will check the server version and edition to see if the it allows for online index rebuilds.
        If the server does support it, it will try to rebuild the index online.
        If the server doesn't support it, it will rebuild the index offline. Be carefull though, this can cause downtime

        The tables must have a clustered index to be able to balance out the data.
        The function does NOT yet support heaps.

        The function will also check if the file groups are subject to balance out.
        A file group would have at least have 2 data files and should be writable.
        If a table is within such a file group it will be subject for processing. If not the table will be skipped.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Database
        The database(s) to process.

    .PARAMETER Table
        The tables(s) of the database to process. If unspecified, all tables will be processed.

    .PARAMETER RebuildOffline
        Will set all the indexes to rebuild offline.
        This option is also needed when the server version is below 2005.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER Force
        This will disable the check for enough disk space for the action to be successful.
        Use this with caution!!

    .NOTES
        Tags: Database, FileManagement, File, Utility
        Author: Sander Stad (@sqlstad), sqlstad.nl

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Invoke-DbaBalanceDataFiles

    .EXAMPLE
        PS C:\> Invoke-DbaBalanceDataFiles -SqlInstance sql1 -Database db1

        This command will distribute the data in database db1 on instance sql1

    .EXAMPLE
        PS C:\> Invoke-DbaBalanceDataFiles -SqlInstance sql1 -Database db1 | Select-Object -ExpandProperty DataFilesEnd

        This command will distribute the data in database db1 on instance sql1

    .EXAMPLE
        PS C:\> Invoke-DbaBalanceDataFiles -SqlInstance sql1 -Database db1 -Table table1,table2,table5

        This command will distribute the data for only the tables table1,table2 and table5

    .EXAMPLE
        PS C:\> Invoke-DbaBalanceDataFiles -SqlInstance sql1 -Database db1 -RebuildOffline

        This command will consider the fact that there might be a SQL Server edition that does not support online rebuilds of indexes.
        By supplying this parameter you give permission to do the rebuilds offline if the edition does not support it.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = "Medium")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Singular Noun doesn't make sense")]
    param (
        [parameter(ParameterSetName = "Pipe", Mandatory)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [object[]]$Database,
        [Alias("Tables")]
        [object[]]$Table,
        [switch]$RebuildOffline,
        [switch]$EnableException,
        [switch]$Force
    )
    begin {
        if ($Force) { $ConfirmPreference = 'none' }
    }
    process {

        Write-Message -Message "Starting balancing out data files" -Level Verbose

        # Set the initial success flag
        [bool]$success = $true

        foreach ($instance in $SqlInstance) {
            # Try connecting to the instance
            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            # Check the database parameter
            if ($Database) {
                if ($Database -notin $server.Databases.Name) {
                    Stop-Function -Message "One or more databases cannot be found on instance on instance $instance" -Target $instance -Continue
                }

                $DatabaseCollection = $server.Databases | Where-Object { $_.Name -in $Database }
            } else {
                Stop-Function -Message "Please supply a database to balance out" -Target $instance -Continue
            }

            # Get the server version
            $serverVersion = $server.Version.Major

            # Check edition of the sql instance
            if ($RebuildOffline) {
                Write-Message -Message "Continuing with offline rebuild." -Level Verbose
            } elseif (-not $RebuildOffline -and ($serverVersion -lt 9 -or (([string]$Server.Edition -notmatch "Developer") -and ($Server.Edition -notmatch "Enterprise")))) {
                # Set up the confirm part
                $message = "The server does not support online rebuilds of indexes. `nDo you want to rebuild the indexes offline?"
                $choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
                $choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
                $options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
                $result = $host.ui.PromptForChoice($title, $message, $options, 0)

                # Check the result from the confirm
                switch ($result) {
                    # If yes
                    0 {
                        # Set the option to generate a full backup
                        Write-Message -Message "Continuing with offline rebuild." -Level Verbose

                        [bool]$supportOnlineRebuild = $false
                    }
                    1 {
                        Stop-Function -Message "You chose to not allow offline rebuilds of indexes. Use -RebuildOffline" -Target $instance
                        return
                    }
                } # switch
            } elseif ($serverVersion -ge 9 -and (([string]$Server.Edition -like "Developer*") -or ($Server.Edition -like "Enterprise*"))) {
                [bool]$supportOnlineRebuild = $true
            }

            # Loop through each of the databases
            foreach ($db in $DatabaseCollection) {
                $dataFilesStarting = Get-DbaDbFile -SqlInstance $server -Database $db.Name | Where-Object { $_.TypeDescription -eq 'ROWS' } | Select-Object ID, LogicalName, PhysicalName, Size, UsedSpace, AvailableSpace | Sort-Object ID

                if (-not $Force) {
                    # Check the amount of disk space available
                    $query = "SELECT SUBSTRING(physical_name, 0, 4) AS 'Drive' ,
                                        SUM(( size * 8 ) / 1024) AS 'SizeMB'
                                FROM	sys.master_files
                                WHERE	DB_NAME(database_id) = '$($db.Name)'
                                GROUP BY SUBSTRING(physical_name, 0, 4)"
                    # Execute the query
                    try {
                        $dbDiskUsage = $Server.Query($query)
                    } catch {
                        $errormsg = Get-ErrorMessage -Record $PSItem
                        Stop-Function -Message "$errormsg" -ErrorRecord $_ -Target $instance -Continue
                    }

                    # Get the free space for each drive
                    try {
                        $result = $Server.Query("xp_fixeddrives")
                    } catch {
                        Stop-Function -Message "Error occurred while finding free space on drives" -ErrorRecord $_ -Target $instance -Continue
                    }
                    $MbFreeColName = $result[0].psobject.Properties.Name[1]
                    $diskFreeSpace = $result | Select-Object Drive, @{ Name = 'FreeMB'; Expression = { $_.$MbFreeColName } }

                    # Loop through each of the drives to see if the size of files on that
                    # particular disk do not exceed the free space of that disk
                    foreach ($d in $dbDiskUsage) {
                        $freeSpace = $diskFreeSpace | Where-Object { $_.Drive -eq $d.Drive.Trim(':\') } | Select-Object FreeMB
                        if ($d.SizeMB -gt $freeSpace.FreeMB) {
                            # Set the success flag
                            $success = $false

                            Stop-Function -Message "The available space may not be sufficient to continue the process. Please use -Force to try anyway." -Target $instance -Continue
                            return
                        }
                    }
                }

                # Create the start time
                $start = Get-Date

                # Check if the function needs to continue
                if ($success) {

                    # Get the database files before all the alterations
                    Write-Message -Message "Retrieving data files before data move" -Level Verbose
                    Write-Message -Message "Processing database $db" -Level Verbose

                    # Check the datafiles of the database
                    $dataFiles = Get-DbaDbFile -SqlInstance $server -Database $db | Where-Object { $_.TypeDescription -eq 'ROWS' }
                    if ($dataFiles.Count -eq 1) {
                        # Set the success flag
                        $success = $false

                        Stop-Function -Message "Database $db only has one data file. Please add a data file to balance out the data" -Target $instance -Continue
                    }

                    # Check the tables parameter
                    if ($Table) {
                        if ($Table -notin $db.Table) {
                            # Set the success flag
                            $success = $false

                            Stop-Function -Message "One or more tables cannot be found in database $db on instance $instance" -Target $instance -Continue
                        }

                        $tableCollection = $db.Tables | Where-Object { $_.Name -in $Table }
                    } else {
                        $tableCollection = $db.Tables
                    }

                    # Get the database file groups and check the aount of data files
                    Write-Message -Message "Retrieving file groups" -Level Verbose
                    $fileGroups = $Server.Databases[$db.Name].FileGroups

                    # ARray to hold the file groups with properties
                    $balanceableTables = @()

                    # Loop through each of the file groups

                    foreach ($fg in $fileGroups) {

                        # If there is less than 2 files balancing out data is not possible
                        if (($fg.Files.Count -ge 2) -and ($fg.Readonly -eq $false)) {
                            $balanceableTables += $fg.EnumObjects() | Where-Object { $_.GetType().Name -eq 'Table' }
                        }
                    }

                    $unsuccessfulTables = @()

                    # Loop through each of the tables
                    foreach ($tbl in $tableCollection) {

                        # Chck if the table balanceable
                        if ($tbl.Name -in $balanceableTables.Name) {

                            Write-Message -Message "Processing table $tbl" -Level Verbose

                            # Chck the tables and get the clustered indexes
                            if ($tableCollection.Indexes.Count -lt 1) {
                                # Set the success flag
                                $success = $false

                                Stop-Function -Message "Table $tbl does not contain any indexes" -Target $instance -Continue
                            } else {

                                # Get all the clustered indexes for the table
                                $clusteredIndexes = $tableCollection.Indexes | Where-Object { $_.IndexType -eq 'ClusteredIndex' }

                                if ($clusteredIndexes.Count -lt 1) {
                                    # Set the success flag
                                    $success = $false

                                    Stop-Function -Message "No clustered indexes found in table $tbl" -Target $instance -Continue
                                }
                            }

                            # Loop through each of the clustered indexes and rebuild them
                            Write-Message -Message "$($clusteredIndexes.Count) clustered index(es) found for table $tbl" -Level Verbose
                            if ($PSCmdlet.ShouldProcess("Rebuilding indexes to balance data")) {
                                foreach ($ci in $clusteredIndexes) {

                                    Write-Message -Message "Rebuilding index $($ci.Name)" -Level Verbose

                                    # Get the original index operation
                                    [bool]$originalIndexOperation = $ci.OnlineIndexOperation

                                    # Set the rebuild option to be either offline or online
                                    if ($RebuildOffline) {
                                        $ci.OnlineIndexOperation = $false
                                    } elseif ($serverVersion -ge 9 -and $supportOnlineRebuild -and -not $RebuildOffline) {
                                        Write-Message -Message "Setting the index operation for index $($ci.Name) to online" -Level Verbose
                                        $ci.OnlineIndexOperation = $true
                                    }

                                    # Rebuild the index
                                    try {
                                        Write-Message -Message "Rebuilding index $($ci.Name)" -Level Verbose
                                        $ci.Rebuild()

                                        # Set the success flag
                                        $success = $true
                                    } catch {
                                        # Set the original index operation back for the index
                                        $ci.OnlineIndexOperation = $originalIndexOperation

                                        # Set the success flag
                                        $success = $false

                                        Stop-Function -Message "Something went wrong rebuilding index $($ci.Name). `n$($_.Exception.Message)" -ErrorRecord $_ -Target $instance -Continue
                                    }

                                    # Set the original index operation back for the index
                                    Write-Message -Message "Setting the index operation for index $($ci.Name) back to the original value" -Level Verbose
                                    $ci.OnlineIndexOperation = $originalIndexOperation

                                } # foreach index

                            } # if process

                        } # if table is balanceable
                        else {
                            # Add the table to the unsuccessful array
                            $unsuccessfulTables += $tbl.Name

                            # Set the success flag
                            $success = $false

                            Write-Message -Message "Table $tbl cannot be balanced out" -Level Verbose
                        }

                    } #foreach table
                }

                # Create the end time
                $end = Get-Date

                # Create the time span
                $timespan = New-TimeSpan -Start $start -End $end
                $ts = [timespan]::fromseconds($timespan.TotalSeconds)
                $elapsed = "{0:HH:mm:ss}" -f ([datetime]$ts.Ticks)

                # Get the database files after all the alterations
                Write-Message -Message "Retrieving data files after data move" -Level Verbose
                $dataFilesEnding = Get-DbaDbFile -SqlInstance $server -Database $db.Name | Where-Object { $_.TypeDescription -eq 'ROWS' } | Select-Object ID, LogicalName, PhysicalName, Size, UsedSpace, AvailableSpace | Sort-Object ID

                [pscustomobject]@{
                    ComputerName   = $server.ComputerName
                    InstanceName   = $server.ServiceName
                    SqlInstance    = $server.DomainInstanceName
                    Database       = $db.Name
                    Start          = $start
                    End            = $end
                    Elapsed        = $elapsed
                    Success        = $success
                    Unsuccessful   = $unsuccessfulTables -join ","
                    DataFilesStart = $dataFilesStarting
                    DataFilesEnd   = $dataFilesEnding
                }

            } # foreach database

        } # end process
    }
}


# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDVJaG7voi2AiGS
# PMYGrIUGF9VQtvLrzto3wvwxsgUX9KCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDwOhX58aHidl3x1lgYuO0bwnL9
# lQ1tlMZaX+3k7Lj6aTANBgkqhkiG9w0BAQEFAASCAQBnFyPJhMdY0fi1Mh/9cKxs
# YuXqCMMIB+xpRbmpw+nSSTFqVLJqrypJ+s3IaXtgcfZWlvgkXbAyKXHrjmJ+iJbw
# CfjWguhniYApN1CXctrV5h4RcnvtUVGHQ03PdwrbrLqPjGtSDbZlntiC9ziBH6df
# o2mMH2blbFMVmsQwi2vnf9Jb2BiEtfIeJPYj22pQ6bXY3mm42rY176UH9XYeVXJS
# CCP6nNaFr2IjoYkZr4JJxaFIN3vouuhXBxzN9Rdq+q9IdNqtnqgIPrXTSJvbvcge
# chqqGNMKzxywSEbeP22GhrbdHJx656hDPejRUNJ7bxpwrp5C25Me/MAdhnDTHFuY
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDYyMFowLwYJKoZIhvcNAQkEMSIE
# IJlhCb3hwBhKewQ/UN9nhRUhog1MP1xz+E80XkwX8m98MA0GCSqGSIb3DQEBAQUA
# BIICAFPp22DzdaLvCxyw1vmgnQUpSSqyTO4NtkA5CPrEyq9j8VwUP8V+i9KNGhQc
# skOJTEaKO3H3jJdj7bvigmYlZCiiKNggJdVDtVihnhrS+fGPUUMu97sW4R7MRB6X
# WtSrwOw/sglR1dRuntml2lgST4KpFqTozoIzs2x+45bDErAatY+HisxKx3PR8owL
# GX/8F2+8tdWyNV2rn58NtOYsXEP+BejlNnPpsty0JO0geYNRArwaTewI+oN58NYU
# C4efQUDmGyya+vmXeIr1l89F0EhEPsEkyAa7OVAllKUDGb7HgVtzAKv4ZhuHz8kB
# UOHsZAGXuFiI3SxOtH6ogVNNNP5xoBiAkFEFiRDdwWVRPGEJ09QBNnRbUpcWP8Vd
# iGkD7O/kamIpukfc2uarDmIcr2WmUQGDzGpNQISAPtdsThmVAaReSL1ut60B/onc
# bS5TA0VwBjs4DNO8M4VkNn9Sp/dctVZwetgqjAnIJ90jhRmMWA7IgewYwihaGAaa
# 1H4HgWyoIJYVdtZnnwP+FKM2tMY+VT2U8shS5kKdfxOydCUAWnXKyVT0yuzmVRhD
# bfTPeANHkTRC1MrYsarX9/kfLNapU1RE0Dy7Wmey+K/POZ+xibqwuXQTEboc/spE
# oVVN7YXHBVHrTx0/Cy3xS9EK51hTaV9TQA+QnrTYGEVmjedz
# SIG # End signature block
