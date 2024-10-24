#
# Module manifest for module 'dbatools'
#
# Generated by: Chrissy LeMaire
#
# Generated on: 9/8/2015
#
@{

    # Script module or binary module file associated with this manifest.
    RootModule             = 'dbatools.psm1'

    # Version number of this module.
    ModuleVersion          = '1.1.145'

    # ID used to uniquely identify this module
    GUID                   = '9d139310-ce45-41ce-8e8b-d76335aa1789'

    # Author of this module
    Author                 = 'the dbatools team'

    # Company or vendor of this module
    CompanyName            = 'dbatools.io'

    # Copyright statement for this module
    Copyright              = 'Copyright (c) 2021 by dbatools, licensed under MIT'

    # Description of the functionality provided by this module
    Description            = "The community module that enables SQL Server Pros to automate database development and server administration"

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion      = '3.0'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName     = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion  = ''

    # Minimum version of the .NET Framework required by this module
    DotNetFrameworkVersion = '4.6.2'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion             = ''

    # Processor architecture (None, X86, Amd64, IA64) required by this module
    ProcessorArchitecture  = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules        = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies     = @()

    # Script files () that are run in the caller's environment prior to importing this module
    ScriptsToProcess       = @()

    # Type files (xml) to be loaded when importing this module
    TypesToProcess         = @("xml\dbatools.Types.ps1xml")

    # Format files (xml) to be loaded when importing this module
    # "xml\dbatools.Format.ps1xml"
    FormatsToProcess       = @("xml\dbatools.Format.ps1xml")

    # Modules to import as nested modules of the module specified in ModuleToProcess
    NestedModules          = @()

    # Functions to export from this module
    # Specific functions to export for Core, etc are also found in psm1
    # FunctionsToExport specifically helps with AUTO-LOADING so do not remove
    FunctionsToExport      = @(
        'Get-DbaDbServiceBrokerQueue',
        'New-DbaLinkedServer',
        'Add-DbaAgDatabase',
        'Add-DbaAgListener',
        'Add-DbaAgReplica',
        'Add-DbaComputerCertificate',
        'Add-DbaDbMirrorMonitor',
        'Add-DbaDbRoleMember',
        'Add-DbaPfDataCollectorCounter',
        'Add-DbaRegServer',
        'Add-DbaRegServerGroup',
        'Add-DbaServerRoleMember',
        'Backup-DbaComputerCertificate',
        'Backup-DbaDatabase',
        'Test-DbaBackupEncrypted',
        'Backup-DbaDbCertificate',
        'Backup-DbaDbMasterKey',
        'Backup-DbaServiceMasterKey',
        'Clear-DbaConnectionPool',
        'Clear-DbaLatchStatistics',
        'Clear-DbaPlanCache',
        'Clear-DbaWaitStatistics',
        'Connect-DbaInstance',
        'ConvertTo-DbaDataTable',
        'ConvertTo-DbaTimeline',
        'ConvertTo-DbaXESession',
        'Copy-DbaAgentAlert',
        'Copy-DbaAgentJob',
        'Copy-DbaAgentJobCategory',
        'Copy-DbaAgentOperator',
        'Copy-DbaAgentProxy',
        'Copy-DbaAgentSchedule',
        'Copy-DbaAgentServer',
        'Copy-DbaBackupDevice',
        'Copy-DbaCredential',
        'Copy-DbaCustomError',
        'Copy-DbaDatabase',
        'Copy-DbaDataCollector',
        'Copy-DbaDbAssembly',
        'Copy-DbaDbMail',
        'Copy-DbaDbQueryStoreOption',
        'Copy-DbaDbTableData',
        'Copy-DbaDbViewData',
        'Copy-DbaEndpoint',
        'Copy-DbaInstanceAudit',
        'Copy-DbaInstanceAuditSpecification',
        'Copy-DbaInstanceTrigger',
        'Copy-DbaLinkedServer',
        'Copy-DbaLogin',
        'Copy-DbaPolicyManagement',
        'Copy-DbaRegServer',
        'Copy-DbaResourceGovernor',
        'Copy-DbaSpConfigure',
        'Copy-DbaStartupProcedure',
        'Copy-DbaSysDbUserObject',
        'Copy-DbaXESession',
        'Copy-DbaXESessionTemplate',
        'Disable-DbaAgHadr',
        'Disable-DbaFilestream',
        'Disable-DbaForceNetworkEncryption',
        'Disable-DbaHideInstance',
        'Disable-DbaStartupProcedure',
        'Disable-DbaTraceFlag',
        'Dismount-DbaDatabase',
        'Enable-DbaAgHadr',
        'Enable-DbaFilestream',
        'Enable-DbaForceNetworkEncryption',
        'Enable-DbaHideInstance',
        'Enable-DbaStartupProcedure',
        'Enable-DbaTraceFlag',
        'Expand-DbaDbLogFile',
        'Export-DbaCredential',
        'Export-DbaDacPackage',
        'Export-DbaDbRole',
        'Export-DbaDbTableData',
        'Export-DbaBinaryFile',
        'Import-DbaBinaryFile',
        'Get-DbaBinaryFileTable',
        'Export-DbaDiagnosticQuery',
        'Export-DbaExecutionPlan',
        'Export-DbaInstance',
        'Export-DbaLinkedServer',
        'Export-DbaLogin',
        'Export-DbaPfDataCollectorSetTemplate',
        'Export-DbaRegServer',
        'Export-DbaRepServerSetting',
        'Export-DbaScript',
        'Export-DbaServerRole',
        'Export-DbaSpConfigure',
        'Export-DbaSysDbUserObject',
        'Export-DbatoolsConfig',
        'Export-DbaUser',
        'Export-DbaXECsv',
        'Export-DbaXESession',
        'Export-DbaXESessionTemplate',
        'Find-DbaAgentJob',
        'Find-DbaBackup',
        'Find-DbaCommand',
        'Find-DbaDatabase',
        'Find-DbaDbDisabledIndex',
        'Find-DbaDbDuplicateIndex',
        'Find-DbaDbGrowthEvent',
        'Find-DbaDbUnusedIndex',
        'Find-DbaInstance',
        'Find-DbaLoginInGroup',
        'Find-DbaOrphanedFile',
        'Find-DbaSimilarTable',
        'Find-DbaStoredProcedure',
        'Find-DbaTrigger',
        'Find-DbaUserObject',
        'Find-DbaView',
        'Format-DbaBackupInformation',
        'Get-DbaAgBackupHistory',
        'Get-DbaAgDatabase',
        'Get-DbaAgentAlert',
        'Get-DbaAgentAlertCategory',
        'Get-DbaAgentJob',
        'Get-DbaAgentJobCategory',
        'Get-DbaAgentJobHistory',
        'Get-DbaAgentJobOutputFile',
        'Get-DbaAgentJobStep',
        'Get-DbaAgentLog',
        'Get-DbaAgentOperator',
        'Get-DbaAgentProxy',
        'Get-DbaAgentSchedule',
        'Get-DbaAgentServer',
        'Get-DbaAgHadr',
        'Get-DbaAgListener',
        'Get-DbaAgReplica',
        'Get-DbaAvailabilityGroup',
        'Get-DbaAvailableCollation',
        'Get-DbaBackupDevice',
        'Get-DbaBackupInformation',
        'Get-DbaBuild',
        'Get-DbaClientAlias',
        'Get-DbaClientProtocol',
        'Get-DbaCmConnection',
        'Get-DbaCmObject',
        'Get-DbaComputerCertificate',
        'Get-DbaComputerSystem',
        'Get-DbaConnection',
        'Get-DbaCpuRingBuffer',
        'Get-DbaCpuUsage',
        'Get-DbaCredential',
        'Get-DbaCustomError',
        'Get-DbaDatabase',
        'Get-DbaDbAssembly',
        'Get-DbaDbAsymmetricKey',
        'Get-DbaDbBackupHistory',
        'Get-DbaDbccHelp',
        'Get-DbaDbccMemoryStatus',
        'Get-DbaDbccProcCache',
        'Get-DbaDbccSessionBuffer',
        'Get-DbaDbccStatistic',
        'Get-DbaDbccUserOption',
        'Get-DbaDbCertificate',
        'Copy-DbaDbCertificate',
        'Get-DbaDbCheckConstraint',
        'Remove-DbaDbCheckConstraint',
        'Get-DbaDbCompatibility',
        'Get-DbaDbCompression',
        'Get-DbaDbDbccOpenTran',
        'Get-DbaDbDetachedFileInfo',
        'Get-DbaDbEncryption',
        'Disable-DbaDbEncryption',
        'Enable-DbaDbEncryption',
        'Get-DbaDbEncryptionKey',
        'New-DbaDbEncryptionKey',
        'Remove-DbaDbEncryptionKey',
        'Start-DbaDbEncryption',
        'Stop-DbaDbEncryption',
        'Get-DbaDbExtentDiff',
        'Get-DbaDbFeatureUsage',
        'Get-DbaDbFile',
        'Get-DbaDbFileGroup',
        'Get-DbaDbFileGrowth',
        'Get-DbaDbFileMapping',
        'Get-DbaDbForeignKey',
        'Get-DbaDbIdentity',
        'Get-DbaDbLogShipError',
        'Get-DbaDbLogSpace',
        'Get-DbaDbMail',
        'Get-DbaDbMailAccount',
        'Get-DbaDbMailConfig',
        'Get-DbaDbMailHistory',
        'Get-DbaDbMailLog',
        'Get-DbaDbMailProfile',
        'Get-DbaDbMailServer',
        'Get-DbaDbMasterKey',
        'Get-DbaDbMemoryUsage',
        'Get-DbaDbMirror',
        'Get-DbaDbMirrorMonitor',
        'Get-DbaDbObjectTrigger',
        'Get-DbaDbOrphanUser',
        'Get-DbaDbPageInfo',
        'Get-DbaDbPartitionFunction',
        'Get-DbaDbPartitionScheme',
        'Remove-DbaDbPartitionScheme',
        'Remove-DbaDbPartitionFunction',
        'Get-DbaDbQueryStoreOption',
        'Get-DbaDbRecoveryModel',
        'Get-DbaDbRestoreHistory',
        'Get-DbaDbRole',
        'Get-DbaDbRoleMember',
        'Get-DbaDbSchema',
        'Get-DbaDbSequence',
        'Get-DbaDbServiceBrokerService',
        'Get-DbaDbSharePoint',
        'Get-DbaDbSnapshot',
        'Get-DbaDbSpace',
        'Get-DbaDbState',
        'Get-DbaDbStoredProcedure',
        'Get-DbaDbSynonym',
        'Get-DbaDbTable',
        'Remove-DbaDbTable',
        'Get-DbaDbTrigger',
        'Get-DbaDbUdf',
        'Get-DbaDbUser',
        'Get-DbaDbUserDefinedTableType',
        'Get-DbaDbView',
        'Get-DbaDbVirtualLogFile',
        'Get-DbaDefaultPath',
        'Get-DbaDependency',
        'Get-DbaDeprecatedFeature',
        'Get-DbaDiskSpace',
        'Get-DbaDump',
        'Get-DbaEndpoint',
        'Get-DbaErrorLog',
        'Get-DbaErrorLogConfig',
        'Get-DbaEstimatedCompletionTime',
        'Get-DbaExecutionPlan',
        'Get-DbaExtendedProtection',
        'Get-DbaExternalProcess',
        'Get-DbaFeature',
        'Get-DbaFile',
        'Get-DbaFilestream',
        'Get-DbaFirewallRule',
        'Get-DbaForceNetworkEncryption',
        'Get-DbaHelpIndex',
        'Get-DbaHideInstance',
        'Get-DbaInstanceAudit',
        'Get-DbaInstanceAuditSpecification',
        'Get-DbaInstalledPatch',
        'Get-DbaInstanceInstallDate',
        'Get-DbaInstanceProperty',
        'Get-DbaInstanceProtocol',
        'Get-DbaInstanceTrigger',
        'Get-DbaInstanceUserOption',
        'Get-DbaIoLatency',
        'Get-DbaKbUpdate',
        'Get-DbaLastBackup',
        'Get-DbaLastGoodCheckDb',
        'Get-DbaLatchStatistic',
        'Get-DbaLinkedServer',
        'Get-DbaLocaleSetting',
        'Get-DbaLogin',
        'Get-DbaMaintenanceSolutionLog',
        'Get-DbaManagementObject',
        'Get-DbaMaxMemory',
        'Get-DbaMemoryCondition',
        'Get-DbaMemoryUsage',
        'Get-DbaModule',
        'Get-DbaMsdtc',
        'Get-DbaNetworkActivity',
        'Get-DbaNetworkCertificate',
        'Get-DbaNetworkConfiguration',
        'Get-DbaOpenTransaction',
        'Get-DbaOperatingSystem',
        'Get-DbaPageFileSetting',
        'Get-DbaPbmCategory',
        'Get-DbaPbmCategorySubscription',
        'Get-DbaPbmCondition',
        'Get-DbaPbmObjectSet',
        'Get-DbaPbmPolicy',
        'Get-DbaPbmStore',
        'Get-DbaPermission',
        'Get-DbaPfAvailableCounter',
        'Get-DbaPfDataCollector',
        'Get-DbaPfDataCollectorCounter',
        'Get-DbaPfDataCollectorCounterSample',
        'Get-DbaPfDataCollectorSet',
        'Get-DbaPfDataCollectorSetTemplate',
        'Get-DbaPlanCache',
        'Get-DbaPowerPlan',
        'Get-DbaPrivilege',
        'Get-DbaProcess',
        'Get-DbaProductKey',
        'Get-DbaQueryExecutionTime',
        'Get-DbaRandomizedDataset',
        'Get-DbaRandomizedDatasetTemplate',
        'Get-DbaRandomizedType',
        'Get-DbaRandomizedValue',
        'Get-DbaRegistryRoot',
        'Get-DbaRegServer',
        'Get-DbaRegServerGroup',
        'Get-DbaRegServerStore',
        'Get-DbaRepDistributor',
        'Get-DbaRepPublication',
        'Get-DbaRepServer',
        'Get-DbaResourceGovernor',
        'Get-DbaRgClassifierFunction',
        'Get-DbaRgResourcePool',
        'Get-DbaRgWorkloadGroup',
        'Get-DbaRunningJob',
        'Get-DbaSchemaChangeHistory',
        'Get-DbaServerRole',
        'Get-DbaServerRoleMember',
        'Get-DbaService',
        'Get-DbaSpConfigure',
        'Get-DbaSpinLockStatistic',
        'Get-DbaSpn',
        'Get-DbaSsisExecutionHistory',
        'Get-DbaStartupParameter',
        'Get-DbaStartupProcedure',
        'Get-DbaSuspectPage',
        'Get-DbaTcpPort',
        'Get-DbaTempdbUsage',
        'Get-DbatoolsChangeLog',
        'Get-DbatoolsConfig',
        'Get-DbatoolsConfigValue',
        'Get-DbatoolsError',
        'Get-DbatoolsLog',
        'Get-DbatoolsPath',
        'Get-DbaTopResourceUsage',
        'Get-DbaTrace',
        'Get-DbaTraceFlag',
        'Get-DbaUptime',
        'Get-DbaUserPermission',
        'Get-DbaWaitingTask',
        'Get-DbaWaitResource',
        'Get-DbaWaitStatistic',
        'Get-DbaWindowsLog',
        'Get-DbaWsfcAvailableDisk',
        'Get-DbaWsfcCluster',
        'Get-DbaWsfcDisk',
        'Get-DbaWsfcNetwork',
        'Get-DbaWsfcNetworkInterface',
        'Get-DbaWsfcNode',
        'Get-DbaWsfcResource',
        'Get-DbaWsfcResourceGroup',
        'Get-DbaWsfcResourceType',
        'Get-DbaWsfcRole',
        'Get-DbaWsfcSharedVolume',
        'Get-DbaXEObject',
        'Get-DbaXESession',
        'Get-DbaXESessionTarget',
        'Get-DbaXESessionTargetFile',
        'Get-DbaXESessionTemplate',
        'Get-DbaXESmartTarget',
        'Get-DbaXEStore',
        'Grant-DbaAgPermission',
        'Import-DbaCsv',
        'Import-DbaPfDataCollectorSetTemplate',
        'Import-DbaRegServer',
        'Import-DbaSpConfigure',
        'Import-DbatoolsConfig',
        'Import-DbaXESessionTemplate',
        'Install-DbaDarlingData',
        'Install-DbaFirstResponderKit',
        'Install-DbaInstance',
        'Install-DbaMaintenanceSolution',
        'Install-DbaMultiTool',
        'Install-DbaSqlWatch',
        'Install-DbatoolsWatchUpdate',
        'Install-DbaWhoIsActive',
        'Invoke-DbaAdvancedInstall',
        'Invoke-DbaAdvancedRestore',
        'Invoke-DbaAdvancedUpdate',
        'Invoke-DbaAgFailover',
        'Invoke-DbaBalanceDataFiles',
        'Invoke-DbaCycleErrorLog',
        'Invoke-DbaDbccDropCleanBuffer',
        'Invoke-DbaDbccFreeCache',
        'Invoke-DbaDbClone',
        'Invoke-DbaDbDataGenerator',
        'Invoke-DbaDbDataMasking',
        'Invoke-DbaDbDbccCheckConstraint',
        'Invoke-DbaDbDbccCleanTable',
        'Invoke-DbaDbDbccUpdateUsage',
        'Invoke-DbaDbDecryptObject',
        'Invoke-DbaDbLogShipping',
        'Invoke-DbaDbLogShipRecovery',
        'Invoke-DbaDbMirrorFailover',
        'Invoke-DbaDbMirroring',
        'Invoke-DbaDbPiiScan',
        'Invoke-DbaDbShrink',
        'Invoke-DbaDbTransfer',
        'Invoke-DbaDbUpgrade',
        'Invoke-DbaDiagnosticQuery',
        'Invoke-DbaPfRelog',
        'Invoke-DbaQuery',
        'Invoke-DbatoolsFormatter',
        'Invoke-DbatoolsRenameHelper',
        'Invoke-DbaWhoIsActive',
        'Invoke-DbaXEReplay',
        'Join-DbaAvailabilityGroup',
        'Join-DbaPath',
        'Measure-DbaBackupThroughput',
        'Measure-DbaDbVirtualLogFile',
        'Measure-DbaDiskSpaceRequirement',
        'Measure-DbatoolsImport',
        'Mount-DbaDatabase',
        'Move-DbaDbFile',
        'Move-DbaRegServer',
        'Move-DbaRegServerGroup',
        'New-DbaAgentAlertCategory',
        'New-DbaAgentJob',
        'New-DbaAgentJobCategory',
        'New-DbaAgentJobStep',
        'New-DbaAgentOperator',
        'New-DbaAgentProxy',
        'New-DbaAgentSchedule',
        'New-DbaAvailabilityGroup',
        'New-DbaAzAccessToken',
        'New-DbaClientAlias',
        'New-DbaCmConnection',
        'New-DbaComputerCertificate',
        'New-DbaComputerCertificateSigningRequest',
        'New-DbaConnectionString',
        'New-DbaConnectionStringBuilder',
        'New-DbaCredential',
        'New-DbaCustomError',
        'New-DbaDacOption',
        'New-DbaDacProfile',
        'New-DbaDatabase',
        'New-DbaDbAsymmetricKey',
        'New-DbaDbCertificate',
        'New-DbaDbDataGeneratorConfig',
        'New-DbaDbFileGroup',
        'New-DbaDbMailAccount',
        'New-DbaDbMailProfile',
        'New-DbaDbMaskingConfig',
        'New-DbaDbMasterKey',
        'New-DbaDbRole',
        'New-DbaDbSchema',
        'New-DbaDbSequence',
        'New-DbaDbSnapshot',
        'New-DbaDbSynonym',
        'New-DbaDbTable',
        'New-DbaDbTransfer',
        'New-DbaDbUser',
        'New-DbaDiagnosticAdsNotebook',
        'New-DbaDirectory',
        'New-DbaEndpoint',
        'New-DbaFirewallRule',
        'New-DbaLogin',
        'New-DbaRgResourcePool',
        'New-DbaScriptingOption',
        'New-DbaServerRole',
        'New-DbaServiceMasterKey',
        'New-DbaSqlParameter',
        'New-DbatoolsSupportPackage',
        'New-DbaXESession',
        'New-DbaXESmartCsvWriter',
        'New-DbaXESmartEmail',
        'New-DbaXESmartQueryExec',
        'New-DbaXESmartReplay',
        'New-DbaXESmartTableWriter',
        'Publish-DbaDacPackage',
        'Read-DbaAuditFile',
        'Read-DbaBackupHeader',
        'Read-DbaTraceFile',
        'Read-DbaTransactionLog',
        'Read-DbaXEFile',
        'Register-DbatoolsConfig',
        'Remove-DbaAgDatabase',
        'Remove-DbaAgentAlertCategory',
        'Remove-DbaAgentAlert',
        'Remove-DbaAgentJob',
        'Remove-DbaAgentJobCategory',
        'Remove-DbaAgentJobStep',
        'Remove-DbaAgentOperator',
        'Remove-DbaAgentSchedule',
        'Remove-DbaAgListener',
        'Remove-DbaAgReplica',
        'Remove-DbaAvailabilityGroup',
        'Remove-DbaBackup',
        'Remove-DbaClientAlias',
        'Remove-DbaCmConnection',
        'Remove-DbaComputerCertificate',
        'Remove-DbaCustomError',
        'Remove-DbaDatabase',
        'Remove-DbaDatabaseSafely',
        'Remove-DbaDbAsymmetricKey',
        'Remove-DbaDbBackupRestoreHistory',
        'Remove-DbaDbCertificate',
        'Remove-DbaDbData',
        'Remove-DbaDbFileGroup',
        'Remove-DbaDbLogShipping',
        'Remove-DbaDbMasterKey',
        'Remove-DbaDbMirror',
        'Remove-DbaDbMirrorMonitor',
        'Remove-DbaDbOrphanUser',
        'Remove-DbaDbRole',
        'Remove-DbaDbRoleMember',
        'Remove-DbaDbSchema',
        'Remove-DbaDbSequence',
        'Remove-DbaDbSnapshot',
        'Remove-DbaDbSynonym',
        'Remove-DbaDbTableData',
        'Remove-DbaDbUser',
        'Remove-DbaDbView',
        'Remove-DbaEndpoint',
        'Remove-DbaFirewallRule',
        'Remove-DbaLinkedServer',
        'Remove-DbaLogin',
        'Remove-DbaNetworkCertificate',
        'Remove-DbaPfDataCollectorCounter',
        'Remove-DbaPfDataCollectorSet',
        'Remove-DbaRegServer',
        'Remove-DbaRegServerGroup',
        'Remove-DbaRgResourcePool',
        'Remove-DbaServerRole',
        'Remove-DbaSpn',
        'Remove-DbaTrace',
        'Remove-DbaXESession',
        'Remove-DbaXESmartTarget',
        'Rename-DbaDatabase',
        'Rename-DbaLogin',
        'Repair-DbaDbMirror',
        'Repair-DbaDbOrphanUser',
        'Repair-DbaInstanceName',
        'Reset-DbaAdmin',
        'Reset-DbatoolsConfig',
        'Resolve-DbaNetworkName',
        'Resolve-DbaPath',
        'Restart-DbaService',
        'Restore-DbaDatabase',
        'Restore-DbaDbCertificate',
        'Restore-DbaDbSnapshot',
        'Resume-DbaAgDbDataMovement',
        'Revoke-DbaAgPermission',
        'Save-DbaDiagnosticQueryScript',
        'Save-DbaKbUpdate',
        'Select-DbaBackupInformation',
        'Select-DbaDbSequenceNextValue',
        'Set-DbaAgentAlert',
        'Set-DbaAgentJob',
        'Set-DbaAgentJobCategory',
        'Set-DbaAgentJobOutputFile',
        'Set-DbaAgentJobOwner',
        'Set-DbaAgentJobStep',
        'Set-DbaAgentSchedule',
        'Set-DbaAgentServer',
        'Set-DbaAgListener',
        'Set-DbaAgReplica',
        'Set-DbaAvailabilityGroup',
        'Set-DbaCmConnection',
        'Set-DbaDbCompatibility',
        'Set-DbaDbCompression',
        'Set-DbaDbFileGroup',
        'Set-DbaDbFileGrowth',
        'Set-DbaDbIdentity',
        'Set-DbaDbMirror',
        'Set-DbaDbOwner',
        'Set-DbaDbQueryStoreOption',
        'Set-DbaDbRecoveryModel',
        'Set-DbaDbSchema',
        'Set-DbaDbSequence',
        'Set-DbaDbState',
        'Set-DbaEndpoint',
        'Set-DbaErrorLogConfig',
        'Set-DbaExtendedProtection',
        'Set-DbaLogin',
        'Set-DbaMaxDop',
        'Set-DbaMaxMemory',
        'Set-DbaNetworkCertificate',
        'Set-DbaNetworkConfiguration',
        'Set-DbaPowerPlan',
        'Set-DbaPrivilege',
        'Set-DbaResourceGovernor',
        'Set-DbaRgResourcePool',
        'Set-DbaSpConfigure',
        'Set-DbaSpn',
        'Set-DbaStartupParameter',
        'Set-DbaTcpPort',
        'Set-DbaTempDbConfig',
        'Set-DbatoolsPath',
        'Show-DbaDbList',
        'Show-DbaInstanceFileSystem',
        'Start-DbaAgentJob',
        'Start-DbaEndpoint',
        'Start-DbaMigration',
        'Start-DbaPfDataCollectorSet',
        'Start-DbaService',
        'Start-DbaTrace',
        'Start-DbaXESession',
        'Start-DbaXESmartTarget',
        'Stop-DbaAgentJob',
        'Stop-DbaEndpoint',
        'Stop-DbaExternalProcess',
        'Stop-DbaPfDataCollectorSet',
        'Stop-DbaProcess',
        'Stop-DbaService',
        'Stop-DbaTrace',
        'Stop-DbaXESession',
        'Stop-DbaXESmartTarget',
        'Suspend-DbaAgDbDataMovement',
        'Sync-DbaAvailabilityGroup',
        'Sync-DbaLoginPermission',
        'Test-DbaAgentJobOwner',
        'Test-DbaAvailabilityGroup',
        'Test-DbaBackupInformation',
        'Test-DbaBuild',
        'Test-DbaCmConnection',
        'Test-DbaComputerCertificateExpiration',
        'Test-DbaConnection',
        'Test-DbaConnectionAuthScheme',
        'Test-DbaDbCollation',
        'Test-DbaDbCompatibility',
        'Test-DbaDbCompression',
        'Test-DbaDbDataGeneratorConfig',
        'Test-DbaDbDataMaskingConfig',
        'Test-DbaDbLogShipStatus',
        'Test-DbaDbOwner',
        'Test-DbaDbQueryStore',
        'Test-DbaDbRecoveryModel',
        'Test-DbaDeprecatedFeature',
        'Test-DbaDiskAlignment',
        'Test-DbaDiskAllocation',
        'Test-DbaDiskSpeed',
        'Test-DbaEndpoint',
        'Test-DbaIdentityUsage',
        'Test-DbaInstanceName',
        'Test-DbaLastBackup',
        'Test-DbaLinkedServerConnection',
        'Test-DbaLoginPassword',
        'Test-DbaManagementObject',
        'Test-DbaMaxDop',
        'Test-DbaMaxMemory',
        'Test-DbaMigrationConstraint',
        'Test-DbaNetworkLatency',
        'Test-DbaOptimizeForAdHoc',
        'Test-DbaPath',
        'Test-DbaPowerPlan',
        'Test-DbaRepLatency',
        'Test-DbaSpn',
        'Test-DbaTempDbConfig',
        'Test-DbaWindowsLogin',
        'Uninstall-DbaSqlWatch',
        'Uninstall-DbatoolsWatchUpdate',
        'Unregister-DbatoolsConfig',
        'Update-DbaBuildReference',
        'Update-DbaInstance',
        'Update-DbaServiceAccount',
        'Update-Dbatools',
        'Watch-DbaDbLogin',
        'Watch-DbatoolsUpdate',
        'Watch-DbaXESession',
        'Write-DbaDbTableData',
        'Set-DbaAgentOperator',
        'Remove-DbaExtendedProperty',
        'Get-DbaExtendedProperty',
        'Set-DbaExtendedProperty',
        'Add-DbaExtendedProperty',
        'Get-DbaOleDbProvider',
        'Get-DbaConnectedInstance',
        'Disconnect-DbaInstance',
        'Set-DbaDefaultPath',
        'Remove-DbaDbUdf',
        'Save-DbaCommunitySoftware',
        'Update-DbaMaintenanceSolution',
        'Remove-DbaServerRoleMember',
        'Remove-DbaDbMailProfile',
        'Remove-DbaDbMailAccount',
        'Set-DbaRgWorkloadGroup',
        'New-DbaRgWorkloadGroup',
        'Remove-DbaRgWorkloadGroup',
        'Get-DbaLinkedServerLogin',
        'New-DbaLinkedServerLogin',
        'Remove-DbaLinkedServerLogin',
        'Remove-DbaCredential',
        'Remove-DbaAgentProxy'
    )

    # Cmdlets to export from this module
    CmdletsToExport        = @(
        'Select-DbaObject',
        'Set-DbatoolsConfig'
    )

    # Variables to export from this module
    VariablesToExport      = ''

    # Aliases to export from this module
    # Aliases are stored in dbatools.psm1
    # The five listed below are intentional
    AliasesToExport        = @(
        'Get-DbaRegisteredServer',
        'Attach-DbaDatabase',
        'Detach-DbaDatabase',
        'Start-SqlMigration',
        'Write-DbaDataTable',
        'Get-DbaDbModule',
        'Get-DbaBuildReference'
    )

    # List of all modules packaged with this module
    ModuleList             = @()

    # List of all files packaged with this module
    FileList               = ''

    PrivateData            = @{
        # PSData is module packaging and gallery metadata embedded in PrivateData
        # It's for rebuilding PowerShellGet (and PoshCode) NuGet-style packages
        # We had to do this because it's the only place we're allowed to extend the manifest
        # https://connect.microsoft.com/PowerShell/feedback/details/421837
        PSData = @{
            # The primary categorization of this module (from the TechNet Gallery tech tree).
            Category     = "Databases"

            # Keyword tags to help users find this module via navigations and search.
            Tags         = @('sqlserver', 'migrations', 'sql', 'dba', 'databases', 'mac', 'linux', 'core')

            # The web address of an icon which can be used in galleries to represent this module
            IconUri      = "https://dbatools.io/logo.png"

            # The web address of this module's project or support homepage.
            ProjectUri   = "https://dbatools.io"

            # The web address of this module's license. Points to a page that's embeddable and linkable.
            LicenseUri   = "https://opensource.org/licenses/MIT"

            # Release notes for this particular version of the module
            ReleaseNotes = "https://dbatools.io/changelog"

            # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
            # RequireLicenseAcceptance = ""

            # Indicates this is a pre-release/testing version of the module.
            IsPrerelease = 'True'
        }
    }
}



# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBM2fMRjyht9FXh
# RWB2EEx+Srd6OClKgqKvuzfbc1eya6CCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCD2dFYpVi/5DVi0zWRctoba/SCa
# LQ7/ys/uLFsaNfQUHDANBgkqhkiG9w0BAQEFAASCAQBuYLoxNmo/n0kz2DWBwoYK
# ZBIGaABXmvlRlpmLWNnzBlCaBqdPWCK4wntnWOxqRAcprQ71Mr+OgNj9Do6LFVwb
# vN3E8yu70rhanfnHiE2eEHBoJCwohNWL92tWAt9oQhikTCyCc1l28bLSk9fWmyka
# 06MIOZOBuLsEGQltLFETG2hbJeXsjxlDnrQCAAW3ZHuHmlhmqcEyV8ovLnrPGNUP
# sruEwt7dHY+dVorm+5S4GTW4mEScpVWV3GagH0iDLGQiaSGBTF0DbXWD6ONHDFGj
# bJZLw3GV+umTKo7YoNmIcZDoW7olI46lMh7mBMtAxv65L37Q6pyQG/aZzRNi3/Da
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MTUyMVowLwYJKoZIhvcNAQkEMSIE
# IPUBk1YdWau2/9sJli0wBblkaQOWx15UUQyASlx2GwWNMA0GCSqGSIb3DQEBAQUA
# BIICAHZeXixC9HYPnGCL6ukYPtD7ZFvbjDopUW2e307i29jmirLiB+9sTmUUue7M
# lx/NCtstrC3OLgC1Eb2xxhqKuOsvlvrI+nbHcup/HW9kEgFAYGVr0Ut4RXu74jum
# PiWsJU9AxAAq368MscZisXWEcYyctfvF8Uaqxc3deKe3bc9cmTNn79cjLbGkg9i/
# +IJt7rRteXgssQIRSHqc6Ks+KNmEq5kM7SpjK1PP8/OwWiH7yeMu3Mg+dUsPYEZz
# mmE2G1JDi/0zyQtoqvL4aCaPxTdIvu0INSGjdNFk73qLY22cBwrCVsUB38K0mns4
# jsqjS1XkFTz9Y8jn+zjCdz0STfNYzDUOQQ2F72buQHjIhQKbcWceHXzwrhQyXftc
# ewaxhR/KHKHIfivN19xIiMIZISPo7Uek8vmviKu08PxC3umzUw8dpKze8RjVsNEw
# aFdCWKL4qhhr1PkSVrGCxE77dqujbGRtG85e36t9hefSNbXMyoMRqpH8fCFhoKKL
# ngqRrBg020B/6jbNU+LEBBp+lg6RYkzbM47Y8QjpCPE9C6pxntzHheSuc1KGjshN
# W9Pt0EjFnram/8FzJ1rO5dqrVq+8P1VgaA1NQ0XThkoYsqCezfgtwr+gyoWsHPsQ
# ErGnM5zBCWvRAGJuJJlUSEhZDe6R54jwPWdDhnIfZYaOEsni
# SIG # End signature block
