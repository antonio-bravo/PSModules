function Add-DbaAgDatabase {
    <#
    .SYNOPSIS
        Adds database(s) to an Availability Group on a SQL Server instance.

    .DESCRIPTION
        Adds database(s) to an Availability Group on a SQL Server instance.

        After checking for prerequisites, the commands runs these five steps for every database:
        * Step 1: Setting seeding mode if needed.
          - If -SeedingMode is used and the current seeding mode of the replica is not in the desired mode, the seeding mode of the replica is changed.
          - The seeding mode will not be changed back but stay in this mode.
          - If the seeding mode is changed to Automatic, the necessary rights to create databases will be granted.
        * Step 2: Running backup and restore if needed.
          - Action is only taken for replicas with a desired seeding mode of Manual and where the database does not yet exist.
          - If -UseLastBackup is used, the restore will be performed based on the backup history of the database.
          - Otherwise a full and log backup will be taken at the primary and those will be restored at the replica using the same folder structure.
        * Step 3: Add the database to the Availability Group on the primary replica.
          - This step is skipped, if the database is already part of the Availability Group.
        * Step 4: Add the database to the Availability Group on the secondary replicas.
          - This step is skipped for those replicas, where the database is already joined to the Availability Group.
        * Step 5: Wait for the database to finish joining the Availability Group on the secondary replicas.

        Use Test-DbaAvailabilityGroup with -AddDatabase to test if all prerequisites are met.

        If you have special requirements for the setup for the database at the replicas,
        perform the backup and restore part with Backup-DbaDatabase and Restore-DbaDatabase in advance.
        Please make sure that the last log backup has been restored before running Add-DbaAgDatabase.

    .PARAMETER SqlInstance
        The primary replica of the Availability Group. Server version must be SQL Server version 2012 or higher.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Database
        The database(s) to add.

    .PARAMETER AvailabilityGroup
        The name of the Availability Group where the databases will be added.

    .PARAMETER Secondary
        Not required - the command will figure this out. But use this parameter if secondary replicas listen on a non default port.
        This parameter can be used to only add the databases on specific secondary replicas.

    .PARAMETER SecondarySqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER InputObject
        Enables piping from Get-DbaDatabase, Get-DbaDbSharePoint and more.

    .PARAMETER SeedingMode
        Specifies how the secondary replica will be initially seeded.

        Automatic enables direct seeding. This method will seed the secondary replica over the network. This method does not require you to backup and restore a copy of the primary database on the replica.

        Manual uses full and log backup to initially transfer the data to the secondary replica. The command skips this if the database is found in restoring state at the secondary replica.

        If not specified, the setting from the availability group replica will be used. Otherwise the setting will be updated.

    .PARAMETER SharedPath
        The network share where the backups will be backed up and restored from.

        Each SQL Server service account must have access to this share.

        NOTE: If a backup / restore is performed, the backups will be left in tact on the network share.

    .PARAMETER UseLastBackup
        Use the last full and log backup of the database. A log backup must be the last backup.

    .PARAMETER AdvancedBackupParams
        Provide additional parameters to the backup command as a hashtable.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: AG, HA
        Author: Chrissy LeMaire (@cl), netnerds.net | Andreas Jordan (@JordanOrdix), ordix.de

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Add-DbaAgDatabase

    .EXAMPLE
        PS C:\> Add-DbaAgDatabase -SqlInstance sql2017a -AvailabilityGroup ag1 -Database db1, db2 -Confirm

        Adds db1 and db2 to ag1 on sql2017a. Prompts for confirmation.

    .EXAMPLE
        PS C:\> Get-DbaDatabase -SqlInstance sql2017a | Out-GridView -Passthru | Add-DbaAgDatabase -AvailabilityGroup ag1

        Adds selected databases from sql2017a to ag1

    .EXAMPLE
        PS C:\> Get-DbaDbSharePoint -SqlInstance sqlcluster | Add-DbaAgDatabase -AvailabilityGroup SharePoint

        Adds SharePoint databases as found in SharePoint_Config on sqlcluster to ag1 on sqlcluster

    .EXAMPLE
        PS C:\> Get-DbaDbSharePoint -SqlInstance sqlcluster -ConfigDatabase SharePoint_Config_2019 | Add-DbaAgDatabase -AvailabilityGroup SharePoint

        Adds SharePoint databases as found in SharePoint_Config_2019 on sqlcluster to ag1 on sqlcluster

    .EXAMPLE
        PS C:\> Add-DbaAgDatabase -SqlInstance sql2017a -AvailabilityGroup ag1 -Database db1 -Secondary sql2017b -SeedingMode Manual -SharedPath \\FS\Backup -AdvancedBackupParams @{ CompressBackup = $true ; FileCount = 3 }

        Adds db1 to ag1 on sql2017a and sql2017b. Uses compression and three files while taking the backups.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(ParameterSetName = 'NonPipeline', Mandatory = $true, Position = 0)]
        [DbaInstanceParameter]$SqlInstance,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [PSCredential]$SqlCredential,
        [Parameter(ParameterSetName = 'NonPipeline', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Pipeline', Mandatory = $true, Position = 0)]
        [string]$AvailabilityGroup,
        [Parameter(ParameterSetName = 'NonPipeline', Mandatory = $true)]
        [string[]]$Database,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [DbaInstanceParameter[]]$Secondary,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [PSCredential]$SecondarySqlCredential,
        [parameter(ValueFromPipeline, ParameterSetName = 'Pipeline', Mandatory = $true)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$InputObject,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [ValidateSet('Automatic', 'Manual')]
        [string]$SeedingMode,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [string]$SharedPath,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [switch]$UseLastBackup,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [hashtable]$AdvancedBackupParams,
        [Parameter(ParameterSetName = 'NonPipeline')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [switch]$EnableException
    )

    begin {
        # We have three while loops, that need a timeout to not loop forever if somethings goes wrong:
        # while ($agDb.State -ne 'Existing')         - should only take milliseconds, so we set a default timeout of one minute
        # while ($replicaAgDb.State -ne 'Existing')  - should only take milliseconds, so we set a default timeout of one minute
        # while ($stillWaiting)                      - can take a long time with automatic seeding, but progress is displayed, so we set a default timeout of one day
        # We will use two timeout configuration values, as we don't want to add more timeout parameters to the command. We will store the timeouts in seconds.
        # The timout for synchronization can be set to a lower value to end the command even when the synchronization is not finished yet.
        # The synchronization will continue even the command or the powershell session stops.
        # Even when the SQL Server instance is restarted, the synchronization will continue after the restart.
        # Set-DbatoolsConfig -FullName commands.add-dbaagdatabase.timeout.existing -Value 60
        # Set-DbatoolsConfig -FullName commands.add-dbaagdatabase.timeout.synchronization -Value 86400
        $timeoutExisting = Get-DbatoolsConfigValue -FullName commands.add-dbaagdatabase.timeout.existing -Fallback 60
        $timeoutSynchronization = Get-DbatoolsConfigValue -FullName commands.add-dbaagdatabase.timeout.synchronization -Fallback 86400

        # While in a while loop, configure the time in milliseconds to wait for the next test:
        # Set-DbatoolsConfig -FullName commands.add-dbaagdatabase.wait.while -Value 100
        $waitWhile = Get-DbatoolsConfigValue -FullName commands.add-dbaagdatabase.wait.while -Fallback 100

        # With automatic seeding we add the current seeding progress in verbose output and a progress bar. This can be disabled:
        # Set-DbatoolsConfig -FullName commands.add-dbaagdatabase.report.seeding -Value $true
        $reportSeeding = Get-DbatoolsConfigValue -FullName commands.add-dbaagdatabase.report.seeding -Fallback $true
    }

    process {
        # We store information for the progress bar in a hashtable suitable for splatting.
        $progress = @{ }
        $progress['Id'] = Get-Random
        $progress['Activity'] = "Adding database(s) to Availability Group $AvailabilityGroup."

        $testResult = @( )

        foreach ($dbName in $Database) {
            try {
                $progress['Status'] = "Test prerequisites for joining database $dbName."
                Write-Progress @progress
                $testSplat = @{
                    SqlInstance            = $SqlInstance
                    SqlCredential          = $SqlCredential
                    Secondary              = $Secondary
                    SecondarySqlCredential = $SecondarySqlCredential
                    AvailabilityGroup      = $AvailabilityGroup
                    AddDatabase            = $dbName
                    UseLastBackup          = $UseLastBackup
                    EnableException        = $true
                }
                if ($SeedingMode) { $testSplat['SeedingMode'] = $SeedingMode }
                if ($SharedPath) { $testSplat['SharedPath'] = $SharedPath }
                $testResult += Test-DbaAvailabilityGroup @testSplat
            } catch {
                Stop-Function -Message "Testing prerequisites for joining database $dbName to Availability Group $AvailabilityGroup failed." -ErrorRecord $_ -Continue
            }
        }

        foreach ($db in $InputObject) {
            try {
                $progress['Status'] = "Test prerequisites for joining database $($db.Name)."
                Write-Progress @progress
                $testSplat = @{
                    SqlInstance            = $db.Parent
                    Secondary              = $Secondary
                    SecondarySqlCredential = $SecondarySqlCredential
                    AvailabilityGroup      = $AvailabilityGroup
                    AddDatabase            = $db.Name
                    UseLastBackup          = $UseLastBackup
                    EnableException        = $true
                }
                if ($SeedingMode) { $testSplat['SeedingMode'] = $SeedingMode }
                if ($SharedPath) { $testSplat['SharedPath'] = $SharedPath }
                $testResult += Test-DbaAvailabilityGroup @testSplat
            } catch {
                Stop-Function -Message "Testing prerequisites for joining database $($db.Name) to Availability Group $AvailabilityGroup failed." -ErrorRecord $_ -Continue
            }
        }

        Write-Message -Level Verbose -Message "Test for prerequisites returned $($testResult.Count) databases that will be joined to the Availability Group $AvailabilityGroup."

        foreach ($result in $testResult) {
            $server = $result.PrimaryServerSMO
            $ag = $result.AvailabilityGroupSMO
            $db = $result.DatabaseSMO
            $replicaServerSMO = $result.ReplicaServerSMO
            $restoreNeeded = $result.RestoreNeeded
            $backups = $result.Backups
            $replicaAgDbSMO = @{ }
            $targetSynchronizationState = @{ }
            $output = @( )

            $progress['Activity'] = "Adding database $($db.Name) to Availability Group $AvailabilityGroup."

            $progress['Status'] = "Step 1/5: Setting seeding mode if needed."
            Write-Message -Level Verbose -Message $progress['Status']
            Write-Progress @progress

            if ($SeedingMode) {
                Write-Message -Level Verbose -Message "Setting seeding mode to $SeedingMode."
                $failure = $false
                foreach ($replicaName in $replicaServerSMO.Keys) {
                    $replica = $ag.AvailabilityReplicas[$replicaName]
                    if ($replica.SeedingMode -ne $SeedingMode) {
                        if ($Pscmdlet.ShouldProcess($server, "Setting seeding mode for replica $replica to $SeedingMode")) {
                            try {
                                Write-Message -Level Verbose -Message "Setting seeding mode for replica $replica to $SeedingMode."
                                $replica.SeedingMode = $SeedingMode
                                $replica.Alter()
                                if ($SeedingMode -eq 'Automatic') {
                                    Write-Message -Level Verbose -Message "Setting GrantAvailabilityGroupCreateDatabasePrivilege on server $($replicaServerSMO[$replicaName]) for Availability Group $AvailabilityGroup."
                                    $null = Grant-DbaAgPermission -SqlInstance $replicaServerSMO[$replicaName] -Type AvailabilityGroup -AvailabilityGroup $AvailabilityGroup -Permission CreateAnyDatabase
                                }
                            } catch {
                                $failure = $true
                                Stop-Function -Message "Failed setting seeding mode for replica $replica to $SeedingMode." -ErrorRecord $_ -Continue
                            }
                        }
                    }
                }
                if ($failure) {
                    Stop-Function -Message "Failed setting seeding mode to $SeedingMode." -Continue
                }
            }

            $progress['Status'] = "Step 2/5: Running backup and restore if needed."
            Write-Message -Level Verbose -Message $progress['Status']
            Write-Progress @progress

            if ($restoreNeeded.Count -gt 0) {
                if (-not $backups) {
                    if ($Pscmdlet.ShouldProcess($server, "Taking full and log backup of database $($db.Name)")) {
                        try {
                            Write-Message -Level Verbose -Message "Taking full and log backup of database $($db.Name)."
                            if ($AdvancedBackupParams) {
                                $fullbackup = $db | Backup-DbaDatabase -BackupDirectory $SharedPath -Type Full -EnableException @AdvancedBackupParams
                                $logbackup = $db | Backup-DbaDatabase -BackupDirectory $SharedPath -Type Log -EnableException @AdvancedBackupParams
                            } else {
                                $fullbackup = $db | Backup-DbaDatabase -BackupDirectory $SharedPath -Type Full -EnableException
                                $logbackup = $db | Backup-DbaDatabase -BackupDirectory $SharedPath -Type Log -EnableException
                            }
                            $backups = $fullbackup, $logbackup
                        } catch {
                            Stop-Function -Message "Failed to take full and log backup of database $($db.Name)." -ErrorRecord $_ -Continue
                        }
                    }
                }
                $failure = $false
                foreach ($replicaName in $restoreNeeded.Keys) {
                    if ($Pscmdlet.ShouldProcess($replicaServerSMO[$replicaName], "Restore database $($db.Name) to replica $replicaName")) {
                        try {
                            Write-Message -Level Verbose -Message "Restore database $($db.Name) to replica $replicaName."
                            $null = $backups | Restore-DbaDatabase -SqlInstance $replicaServerSMO[$replicaName] -NoRecovery -TrustDbBackupHistory -ReuseSourceFolderStructure -EnableException
                        } catch {
                            $failure = $true
                            Stop-Function -Message "Failed to restore database $($db.Name) to replica $replicaName." -ErrorRecord $_ -Continue
                        }
                    }
                }
                if ($failure) {
                    Stop-Function -Message "Failed to restore database $($db.Name)." -Continue
                }
            }

            $progress['Status'] = "Step 3/5: Add the database to the Availability Group on the primary replica."
            Write-Message -Level Verbose -Message $progress['Status']

            if ($Pscmdlet.ShouldProcess($server, "Add database $($db.Name) to Availability Group $AvailabilityGroup on the primary replica")) {
                try {
                    $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) on is not yet known."
                    Write-Message -Level Verbose -Message "Object of type AvailabilityDatabase for $($db.Name) will be created. $($progress['CurrentOperation'])"
                    Write-Progress @progress

                    if ($ag.AvailabilityDatabases.Name -contains $db.Name) {
                        Write-Message -Level Verbose -Message "Database $($db.Name) is already joined to Availability Group $AvailabilityGroup. No action will be taken on the primary replica."
                    } else {
                        $agDb = Get-DbaAgDatabase -SqlInstance $server -AvailabilityGroup $ag.Name -Database $db.Name
                        $agDb = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityDatabase($ag, $db.Name)
                        $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) is $($agDb.State)."
                        Write-Message -Level Verbose -Message "Object of type AvailabilityDatabase for $($db.Name) is created. $($progress['CurrentOperation'])"
                        Write-Progress @progress

                        $agDb.Create()
                        $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) is $($agDb.State)."
                        Write-Message -Level Verbose -Message "Method Create of AvailabilityDatabase for $($db.Name) is executed. $($progress['CurrentOperation'])"
                        Write-Progress @progress

                        # Wait for state to become Existing
                        # https://docs.microsoft.com/en-us/dotnet/api/microsoft.sqlserver.management.smo.sqlsmostate
                        $timeout = (Get-Date).AddSeconds($timeoutExisting)
                        while ($agDb.State -ne 'Existing') {
                            $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) is $($agDb.State), waiting for Existing."
                            Write-Message -Level Verbose -Message $progress['CurrentOperation']
                            Write-Progress @progress

                            if ((Get-Date) -gt $timeout) {
                                Stop-Function -Message "Failed to add database $($db.Name) to Availability Group $AvailabilityGroup. Timeout of $timeoutExisting seconds is reached. State of AvailabilityDatabase for $($db.Name) is still $($agDb.State)." -Continue
                            }
                            Start-Sleep -Milliseconds $waitWhile
                            $agDb.Refresh()
                        }

                        # Get customized SMO for the output
                        $output += Get-DbaAgDatabase -SqlInstance $server -AvailabilityGroup $AvailabilityGroup -Database $db.Name -EnableException
                    }
                } catch {
                    Stop-Function -Message "Failed to add database $($db.Name) to Availability Group $AvailabilityGroup" -ErrorRecord $_ -Continue
                }
            }

            $progress['Status'] = "Step 4/5: Add the database to the Availability Group on the secondary replicas."
            Write-Message -Level Verbose -Message $progress['Status']

            $failure = $false
            foreach ($replicaName in $replicaServerSMO.Keys) {
                if ($Pscmdlet.ShouldProcess($replicaServerSMO[$replicaName], "Add database $($db.Name) to Availability Group $AvailabilityGroup on replica $replicaName")) {
                    $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) on replica $replicaName is not yet known."
                    Write-Message -Level Verbose -Message $progress['CurrentOperation']
                    Write-Progress @progress

                    try {
                        $replicaAgDb = Get-DbaAgDatabase -SqlInstance $replicaServerSMO[$replicaName] -AvailabilityGroup $AvailabilityGroup -Database $db.Name -EnableException
                    } catch {
                        $failure = $true
                        Stop-Function -Message "Failed to get database $($db.Name) on replica $replicaName." -ErrorRecord $_ -Continue
                    }

                    if ($replicaAgDb.IsJoined) {
                        Write-Message -Level Verbose -Message "Database $($db.Name) is already joined to Availability Group $AvailabilityGroup. No action will be taken on the replica $replicaName."
                        $replicaAgDbSMO[$replicaName] = $replicaAgDb
                    } else {
                        # Save SMO in array for the output
                        $output += $replicaAgDb
                        # Save SMO in hashtable for further processing
                        $replicaAgDbSMO[$replicaName] = $replicaAgDb
                        # Save target targetSynchronizationState for further processing
                        # https://docs.microsoft.com/en-us/dotnet/api/microsoft.sqlserver.management.smo.availabilityreplicaavailabilitymode
                        # https://docs.microsoft.com/en-us/dotnet/api/microsoft.sqlserver.management.smo.availabilitydatabasesynchronizationstate
                        $availabilityMode = $ag.AvailabilityReplicas[$replicaName].AvailabilityMode
                        if ($availabilityMode -eq 'AsynchronousCommit') {
                            $targetSynchronizationState[$replicaName] = 'Synchronizing'
                        } elseif ($availabilityMode -eq 'SynchronousCommit') {
                            $targetSynchronizationState[$replicaName] = 'Synchronized'
                        } else {
                            $failure = $true
                            Stop-Function -Message "Unexpected value '$availabilityMode' for AvailabilityMode on replica $replicaName." -Continue
                        }

                        $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) on replica $replicaName is $($replicaAgDb.State)."
                        Write-Message -Level Verbose -Message $progress['CurrentOperation']
                        Write-Progress @progress

                        # https://docs.microsoft.com/en-us/dotnet/api/microsoft.sqlserver.management.smo.sqlsmostate
                        $timeout = (Get-Date).AddSeconds($timeoutExisting)
                        while ($replicaAgDb.State -ne 'Existing') {
                            $progress['CurrentOperation'] = "State of AvailabilityDatabase for $($db.Name) on replica $replicaName is $($replicaAgDb.State), waiting for Existing."
                            Write-Message -Level Verbose -Message $progress['CurrentOperation']
                            Write-Progress @progress

                            if ((Get-Date) -gt $timeout) {
                                Stop-Function -Message "Failed to add database $($db.Name) on replica $replicaName. Timeout of $timeoutExisting seconds is reached. State of AvailabilityDatabase for $db is still $($replicaAgDb.State)." -Continue
                            }
                            Start-Sleep -Milliseconds $waitWhile
                            $replicaAgDb.Refresh()
                        }

                        # With automatic seeding, .JoinAvailablityGroup() is not needed, just wait for the magic to happen
                        if ($ag.AvailabilityReplicas[$replicaName].SeedingMode -ne 'Automatic') {
                            try {
                                $progress['CurrentOperation'] = "Joining database $($db.Name) on replica $replicaName."
                                Write-Message -Level Verbose -Message $progress['CurrentOperation']
                                Write-Progress @progress

                                $replicaAgDb.JoinAvailablityGroup()
                            } catch {
                                $failure = $true
                                Stop-Function -Message "Failed to join database $($db.Name) on replica $replicaName." -ErrorRecord $_ -Continue
                            }
                        }
                    }
                }
            }
            if ($failure) {
                Stop-Function -Message "Failed to add or join database $($db.Name)." -Continue
            }

            # Now we have configured everything and we only have to wait...

            $progress['Status'] = "Step 5/5: Wait for the database to finish joining the Availability Group on the secondary replicas."
            $progress['CurrentOperation'] = ''
            Write-Message -Level Verbose -Message $progress['Status']
            Write-Progress @progress

            if ($Pscmdlet.ShouldProcess($server, "Wait for the database $($db.Name) to finish joining the Availability Group $AvailabilityGroup on the secondary replicas.")) {
                # We need to setup a progress bar for every replica to display them all at once.
                $syncProgressId = @{ }
                foreach ($replicaName in $replicaServerSMO.Keys) {
                    $syncProgressId[$replicaName] = Get-Random
                }

                $stillWaiting = $true
                $timeout = (Get-Date).AddSeconds($timeoutSynchronization)
                while ($stillWaiting) {
                    $stillWaiting = $false
                    $failure = $false
                    foreach ($replicaName in $replicaServerSMO.Keys) {
                        if (-not $targetSynchronizationState[$replicaName]) {
                            Write-Message -Level Verbose -Message "Database $($db.Name) is already joined to Availability Group $AvailabilityGroup. No action will be taken on the replica $replicaName."
                            continue
                        }

                        if (-not $replicaAgDbSMO[$replicaName].IsJoined -or $replicaAgDbSMO[$replicaName].SynchronizationState -ne $targetSynchronizationState[$replicaName]) {
                            $stillWaiting = $true
                        }

                        $syncProgress = @{ }
                        $syncProgress['Id'] = $syncProgressId[$replicaName]
                        $syncProgress['ParentId'] = $progress['Id']
                        $syncProgress['Activity'] = "Adding database(s) to Availability Group $AvailabilityGroup."
                        if ($replicaAgDbSMO[$replicaName].SynchronizationState -ne $targetSynchronizationState[$replicaName]) {
                            $syncProgress['Status'] = "IsJoined is $($replicaAgDbSMO[$replicaName].IsJoined), SynchronizationState is $($replicaAgDbSMO[$replicaName].SynchronizationState), waiting for $($targetSynchronizationState[$replicaName])."
                        } else {
                            $syncProgress['Status'] = "IsJoined is $($replicaAgDbSMO[$replicaName].IsJoined), SynchronizationState is $($replicaAgDbSMO[$replicaName].SynchronizationState), replica is in desired state."
                        }
                        if ($ag.AvailabilityReplicas[$replicaName].SeedingMode -eq 'Automatic' -and $reportSeeding) {
                            $seedingStats = $server.Query("SELECT TOP 1 * FROM sys.dm_hadr_physical_seeding_stats WHERE local_database_name = '$($db.Name)' AND remote_machine_name = '$($ag.AvailabilityReplicas[$replicaName].EndpointUrl)' ORDER BY start_time_utc DESC")
                            if ($seedingStats) {
                                if ($seedingStats.failure_message -ne [DBNull]::Value) {
                                    $failure = $true
                                    Stop-Function -Message "Failed while seeding database $($db.Name) to $replicaName. failure_message: $($seedingStats.failure_message)." -Continue
                                }

                                $syncProgress['PercentComplete'] = [int]($seedingStats.transferred_size_bytes * 100.0 / $seedingStats.database_size_bytes)
                                $syncProgress['SecondsRemaining'] = [int](($seedingStats.estimate_time_complete_utc - (Get-Date).ToUniversalTime()).TotalSeconds)
                                $syncProgress['CurrentOperation'] = "Seeding state: $($seedingStats.internal_state_desc), $([int]($seedingStats.transferred_size_bytes/1024/1024)) out of $([int]($seedingStats.database_size_bytes/1024/1024)) MB transferred."
                            }
                        }
                        Write-Message -Level Verbose -Message ($syncProgress['Status'] + $syncProgress['CurrentOperation'])
                        Write-Progress @syncProgress
                    }
                    if ($failure) {
                        $stillWaiting = $false
                        Stop-Function -Message "Failed while seeding database $($db.Name)." -Continue
                    }

                    if ((Get-Date) -gt $timeout) {
                        $stillWaiting = $false
                        $failure = $true
                        Stop-Function -Message "Failed to join or synchronize database $($db.Name). Timeout of $timeoutSynchronization seconds is reached. $progressOperation" -Continue
                    }
                    Start-Sleep -Milliseconds $waitWhile

                    foreach ($replicaName in $replicaServerSMO.Keys) {
                        $replicaAgDbSMO[$replicaName].Refresh()
                    }
                }
                if ($failure) {
                    Stop-Function -Message "Failed to join or synchronize database $($db.Name)." -Continue
                }
            }
            $output
        }
    }
}



# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKRQ/du3WaSpVR
# lPndwsmR0molXeAKmbH0i7QDRTrqN6CCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCCW9/94qfPSOdScGU4nN7/K82XT
# XxUKCyx/uMPEDQIC1DANBgkqhkiG9w0BAQEFAASCAQA0SgF0dKIe1kfOhdZUhimS
# fcmd1phGM79cHLeLkAREZIIpTPd9fFeNgRD2WjYaytVjGZt5hN1Irq03jU3hXBSd
# zCoRKKcD20HeGKEfNkx9Whwn8YXuWRAu6bbD+HQ1iro5UV1K0cni7yLHJJCEpaxA
# YagsXamVp4mMMZA1KBzLUw9WZfVmuxZrWsPmJll/8GzGhbscPbpIsBc4x7KpfHjL
# S8shWjzxR80j/XVyRWa2ykncSggSaZRmExFoTBMpe2IHa15irMCcJQHZh+HyW8o0
# 3m27nQ2U93c5q+4JYs85vIg5n8d5cNHsZE+DMdfpqfgURAHvc+kjJaH7AuuBdGfi
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDQzOVowLwYJKoZIhvcNAQkEMSIE
# IACbHYSshBo+kox6OSqrPm+1KrmW/eetUF8cSwpITDDWMA0GCSqGSIb3DQEBAQUA
# BIICAHNFiwXhuqAbjTN2H7qhiXawIuCnlQyjjdZtlgyzXiglxno0TeilSxP69kus
# PkVfcSh1Yu/JAT0Yesh3dD3rEvY37Ig9ZbUIwIqXrnbv0AzpmTd6LBF/Vy1I0ccd
# CJhvOzb+ZIukIZcoqBdb24etaLsLjzd3g573dHoC24KDwXmRA/xwxAfQ+vpBa0jW
# KmV4QRG9JLTJ6cgDRppjYIHmjajXrW6gr0O56y27Clke4sjsJShswo8rXO6+W7dp
# i8HDpMOf9nkugcdOzN2/Y964BL4okc5X99y0uKKpc80WMjg1GnVDXe/T4qkIDEN8
# j8N6RcmctZbxOLvHoNx5CynFhonk5r5f0mkbXX9pLFc8MiVRHMlPX2v3Szf6UItd
# aXrD4QnPuvJ7+L65LLYwEsPRga8RYPDk5RceLDTJXWs+RAP6aPk6/INKEN784b73
# ARhTyoJh9xfCELUrD0N6Fi0pm4PYuUoA+b3yLbR5mcANbO3WHvVIDjLE9EY/pNPx
# L2ShnbhbjcJD8v9ySkzjFJL4nNtcT+uZ7/NheWmR0W+fCB/hCcasrZdv2u4InI7c
# vGboyIYmtch0a56nnBWgWDG/Fmvp4vDfDKlsRCjN/6xYoTwl3iuK2rtGGDWGQ/ef
# +fv6tVpnYdCNeitjTj5sWbWJonEdID8GrZUQdJpjR5whQ3bE
# SIG # End signature block
