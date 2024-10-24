function Invoke-DbatoolsRenameHelper {
    <#
    .SYNOPSIS
        Older dbatools command names have been changed. This script helps keep up.

    .DESCRIPTION
        Older dbatools command names have been changed. This script helps keep up.

    .PARAMETER InputObject
        A piped in object from Get-ChildItem

    .PARAMETER Encoding
        Specifies the file encoding. The default is UTF8.

        Valid values are:
        -- ASCII: Uses the encoding for the ASCII (7-bit) character set.
        -- BigEndianUnicode: Encodes in UTF-16 format using the big-endian byte order.
        -- Byte: Encodes a set of characters into a sequence of bytes.
        -- String: Uses the encoding type for a string.
        -- Unicode: Encodes in UTF-16 format using the little-endian byte order.
        -- UTF7: Encodes in UTF-7 format.
        -- UTF8: Encodes in UTF-8 format.
        -- Unknown: The encoding type is unknown or invalid. The data can be treated as binary.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command

    .NOTES
        Tags: Module
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Invoke-DbatoolsRenameHelper

    .EXAMPLE
        PS C:\> Get-ChildItem C:\temp\ps\*.ps1 -Recurse | Invoke-DbatoolsRenameHelper

        Checks to see if any ps1 file in C:\temp\ps matches an old command name.
        If so, then the command name within the text is updated and the resulting changes are written to disk in UTF-8.

    .EXAMPLE
        PS C:\> Get-ChildItem C:\temp\ps\*.ps1 -Recurse | Invoke-DbatoolsRenameHelper -Encoding Ascii -WhatIf

        Shows what would happen if the command would run. If the command would run and there were matches,
        the resulting changes would be written to disk as Ascii encoded.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo[]]$InputObject,
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Byte', 'String', 'Unicode', 'UTF7', 'UTF8', 'Unknown')]
        [string]$Encoding = 'UTF8',
        [switch]$EnableException
    )
    begin {
        $paramrenames = @{
            ExcludeAllSystemDb = 'ExcludeSystem'
            ExcludeAllUserDb   = 'ExcludeUser'
            'Invoke-Sqlcmd2'   = 'Invoke-DbaQuery'
            NetworkShare       = 'SharedPath'
            NoDatabases        = 'ExcludeDatabases'
            NoDisabledJobs     = 'ExcludeDisabledJobs'
            NoJobs             = 'ExcludeJobs'
            NoJobSteps         = 'ExcludeJobSteps'
            NoQueryTextColumn  = 'ExcludeQueryTextColumn'
            NoSystem           = 'ExcludeSystemLogins'
            NoSystemDb         = 'ExcludeSystem'
            NoSystemLogins     = 'ExcludeSystemLogins'
            NoSystemObjects    = 'ExcludeSystemObjects'
            NoSystemSpid       = 'ExcludeSystemSpids'
            UseLastBackups     = 'UseLastBackup'
            PasswordExpiration = 'PasswordExpirationEnabled'
            PasswordPolicy     = 'PasswordPolicyEnforced'
            ServerInstance     = 'SqlInstance'
        }

        $commandrenames = @{
            'Find-DbaDuplicateIndex'            = 'Find-DbaDbDuplicateIndex'
            'Find-DbaDisabledIndex'             = 'Find-DbaDbDisabledIndex'
            'Add-DbaRegisteredServer'           = 'Add-DbaRegServer'
            'Add-DbaRegisteredServerGroup'      = 'Add-DbaRegServerGroup'
            'Backup-DbaDatabaseCertificate'     = 'Backup-DbaDbCertificate'
            'Backup-DbaDatabaseMasterKey'       = 'Backup-DbaDbMasterKey'
            'Clear-DbaSqlConnectionPool'        = 'Clear-DbaConnectionPool'
            'Connect-DbaServer'                 = 'Connect-DbaInstance'
            'Copy-DbaAgentCategory'             = 'Copy-DbaAgentJobCategory'
            'Copy-DbaAgentProxyAccount'         = 'Copy-DbaAgentProxy'
            'Copy-DbaAgentSharedSchedule'       = 'Copy-DbaAgentSchedule'
            'Copy-DbaCentralManagementServer'   = 'Copy-DbaRegServer'
            'Copy-DbaDatabaseAssembly'          = 'Copy-DbaDbAssembly'
            'Copy-DbaDatabaseMail'              = 'Copy-DbaDbMail'
            'Copy-DbaExtendedEvent'             = 'Copy-DbaXESession'
            'Copy-DbaQueryStoreConfig'          = 'Copy-DbaDbQueryStoreOption'
            'Copy-DbaSqlDataCollector'          = 'Copy-DbaDataCollector'
            'Copy-DbaSqlPolicyManagement'       = 'Copy-DbaPolicyManagement'
            'Copy-DbaSqlServerAgent'            = 'Copy-DbaAgentServer'
            'Copy-DbaTableData'                 = 'Copy-DbaDbTableData'
            'Copy-SqlAgentCategory'             = 'Copy-DbaAgentJobCategory'
            'Copy-SqlAlert'                     = 'Copy-DbaAgentAlert'
            'Copy-SqlAudit'                     = 'Copy-DbaInstanceAudit'
            'Copy-SqlAuditSpecification'        = 'Copy-DbaInstanceAuditSpecification'
            'Copy-SqlBackupDevice'              = 'Copy-DbaBackupDevice'
            'Copy-SqlCentralManagementServer'   = 'Copy-DbaRegServer'
            'Copy-SqlCredential'                = 'Copy-DbaCredential'
            'Copy-SqlCustomError'               = 'Copy-DbaCustomError'
            'Copy-SqlDatabase'                  = 'Copy-DbaDatabase'
            'Copy-SqlDatabaseAssembly'          = 'Copy-DbaDbAssembly'
            'Copy-SqlDatabaseMail'              = 'Copy-DbaDbMail'
            'Copy-SqlDataCollector'             = 'Copy-DbaDataCollector'
            'Copy-SqlEndpoint'                  = 'Copy-DbaEndpoint'
            'Copy-SqlExtendedEvent'             = 'Copy-DbaXESession'
            'Copy-SqlJob'                       = 'Copy-DbaAgentJob'
            'Copy-SqlJobServer'                 = 'Copy-SqlInstanceAgent'
            'Copy-SqlLinkedServer'              = 'Copy-DbaLinkedServer'
            'Copy-SqlLogin'                     = 'Copy-DbaLogin'
            'Copy-SqlOperator'                  = 'Copy-DbaAgentOperator'
            'Copy-SqlPolicyManagement'          = 'Copy-DbaPolicyManagement'
            'Copy-SqlProxyAccount'              = 'Copy-DbaAgentProxy'
            'Copy-SqlResourceGovernor'          = 'Copy-DbaResourceGovernor'
            'Copy-SqlInstanceAgent'             = 'Copy-DbaAgentServer'
            'Copy-SqlInstanceTrigger'           = 'Copy-DbaInstanceTrigger'
            'Copy-SqlSharedSchedule'            = 'Copy-DbaAgentSchedule'
            'Copy-SqlSpConfigure'               = 'Copy-DbaSpConfigure'
            'Copy-SqlSsisCatalog'               = 'Copy-DbaSsisCatalog'
            'Copy-SqlSysDbUserObjects'          = 'Copy-DbaSysDbUserObject'
            'Copy-SqlUserDefinedMessage'        = 'Copy-SqlCustomError'
            'Expand-DbaTLogResponsibly'         = 'Expand-DbaDbLogFile'
            'Expand-SqlTLogResponsibly'         = 'Expand-DbaDbLogFile'
            'Export-DbaDacpac'                  = 'Export-DbaDacPackage'
            'Export-DbaRegisteredServer'        = 'Export-DbaRegServer'
            'Export-SqlLogin'                   = 'Export-DbaLogin'
            'Export-SqlSpConfigure'             = 'Export-DbaSpConfigure'
            'Export-SqlUser'                    = 'Export-DbaUser'
            'Find-DbaDatabaseGrowthEvent'       = 'Find-DbaDbGrowthEvent'
            'Find-SqlDuplicateIndex'            = 'Find-DbaDbDuplicateIndex'
            'Find-SqlUnusedIndex'               = 'Find-DbaDbUnusedIndex'
            'Get-DbaRegServerName'              = 'Get-DbaRegServer'
            'Get-DbaConfig'                     = 'Get-DbatoolsConfig'
            'Get-DbaConfigValue'                = 'Get-DbatoolsConfigValue'
            'Get-DbaDatabaseAssembly'           = 'Get-DbaDbAssembly'
            'Get-DbaDatabaseCertificate'        = 'Get-DbaDbCertificate'
            'Get-DbaDatabaseEncryption'         = 'Get-DbaDbEncryption'
            'Get-DbaDatabaseFile'               = 'Get-DbaDbFile'
            'Get-DbaDatabaseFreeSpace'          = 'Get-DbaDbSpace'
            'Get-DbaDatabaseMasterKey'          = 'Get-DbaDbMasterKey'
            'Get-DbaDatabasePartitionFunction'  = 'Get-DbaDbPartitionFunction'
            'Get-DbaDatabasePartitionScheme'    = 'Get-DbaDbPartitionScheme'
            'Get-DbaDatabaseSnapshot'           = 'Get-DbaDbSnapshot'
            'Get-DbaDatabaseSpace'              = 'Get-DbaDbSpace'
            'Get-DbaDatabaseState'              = 'Get-DbaDbState'
            'Get-DbaDatabaseUdf'                = 'Get-DbaDbUdf'
            'Get-DbaDatabaseUser'               = 'Get-DbaDbUser'
            'Get-DbaDatabaseView'               = 'Get-DbaDbView'
            'Get-DbaDbQueryStoreOptions'        = 'Get-DbaDbQueryStoreOption'
            'Get-DbaDistributor'                = 'Get-DbaRepDistributor'
            'Get-DbaInstance'                   = 'Connect-DbaInstance'
            'Get-DbaJobCategory'                = 'Get-DbaAgentJobCategory'
            'Get-DbaLog'                        = 'Get-DbaErrorLog'
            'Get-DbaLogShippingError'           = 'Get-DbaDbLogShipError'
            'Get-DbaOrphanUser'                 = 'Get-DbaDbOrphanUser'
            'Get-DbaPolicy'                     = 'Get-DbaPbmPolicy'
            'Get-DbaQueryStoreConfig'           = 'Get-DbaDbQueryStoreOption'
            'Get-DbaRegisteredServerGroup'      = 'Get-DbaRegServerGroup'
            'Get-DbaRegisteredServerStore'      = 'Get-DbaRegServerStore'
            'Get-DbaRestoreHistory'             = 'Get-DbaDbRestoreHistory'
            'Get-DbaRoleMember'                 = 'Get-DbaDbRoleMember'
            'Get-DbaSqlBuildReference'          = 'Get-DbaBuild'
            'Get-DbaSqlFeature'                 = 'Get-DbaFeature'
            'Get-DbaSqlInstanceProperty'        = 'Get-DbaInstanceProperty'
            'Get-DbaSqlInstanceUserOption'      = 'Get-DbaInstanceUserOption'
            'Get-DbaSqlManagementObject'        = 'Get-DbaManagementObject'
            'Get-DbaSqlModule'                  = 'Get-DbaModule'
            'Get-DbaSqlProductKey'              = 'Get-DbaProductKey'
            'Get-DbaSqlRegistryRoot'            = 'Get-DbaRegistryRoot'
            'Get-DbaSqlService'                 = 'Get-DbaService'
            'Get-DbaTable'                      = 'Get-DbaDbTable'
            'Get-DbaTraceFile'                  = 'Get-DbaTrace'
            'Get-DbaUserLevelPermission'        = 'Get-DbaUserPermission'
            'Get-DbaXEventSession'              = 'Get-DbaXESession'
            'Get-DbaXEventSessionTarget'        = 'Get-DbaXESessionTarget'
            'Get-DiskSpace'                     = 'Get-DbaDiskSpace'
            'Get-SqlMaxMemory'                  = 'Get-DbaMaxMemory'
            'Get-SqlRegisteredServerName'       = 'Get-DbaRegServer'
            'Get-SqlInstanceKey'                = 'Get-DbaProductKey'
            'Import-DbaCsvToSql'                = 'Import-DbaCsv'
            'Import-DbaRegisteredServer'        = 'Import-DbaRegServer'
            'Import-SqlSpConfigure'             = 'Import-DbaSpConfigure'
            'Install-SqlWhoIsActive'            = 'Install-DbaWhoIsActive'
            'Invoke-DbaCmd'                     = 'Invoke-DbaQuery'
            'Invoke-DbaDatabaseClone'           = 'Invoke-DbaDbClone'
            'Invoke-DbaDatabaseShrink'          = 'Invoke-DbaDbShrink'
            'Invoke-DbaDatabaseUpgrade'         = 'Invoke-DbaDbUpgrade'
            'Invoke-DbaLogShipping'             = 'Invoke-DbaDbLogShipping'
            'Invoke-DbaLogShippingRecovery'     = 'Invoke-DbaDbLogShipRecovery'
            'Invoke-DbaSqlQuery'                = 'Invoke-DbaQuery'
            'Move-DbaRegisteredServer'          = 'Move-DbaRegServer'
            'Move-DbaRegisteredServerGroup'     = 'Move-DbaRegServerGroup'
            'New-DbaDatabaseCertificate'        = 'New-DbaDbCertificate'
            'New-DbaDatabaseMasterKey'          = 'New-DbaDbMasterKey'
            'New-DbaDatabaseSnapshot'           = 'New-DbaDbSnapshot'
            'New-DbaPublishProfile'             = 'New-DbaDacProfile'
            'New-DbaSqlConnectionString'        = 'New-DbaConnectionString'
            'New-DbaSqlConnectionStringBuilder' = 'New-DbaConnectionStringBuilder'
            'New-DbaSqlDirectory'               = 'New-DbaDirectory'
            'Out-DbaDataTable'                  = 'ConvertTo-DbaDataTable'
            'Publish-DbaDacpac'                 = 'Publish-DbaDacPackage'
            'Read-DbaXEventFile'                = 'Read-DbaXEFile'
            'Register-DbaConfig'                = 'Register-DbatoolsConfig'
            'Remove-DbaDatabaseCertificate'     = 'Remove-DbaDbCertificate'
            'Remove-DbaDatabaseMasterKey'       = 'Remove-DbaDbMasterKey'
            'Remove-DbaDatabaseSnapshot'        = 'Remove-DbaDbSnapshot'
            'Remove-DbaOrphanUser'              = 'Remove-DbaDbOrphanUser'
            'Remove-DbaRegisteredServer'        = 'Remove-DbaRegServer'
            'Remove-DbaRegisteredServerGroup'   = 'Remove-DbaRegServerGroup'
            'Remove-SqlDatabaseSafely'          = 'Remove-DbaDatabaseSafely'
            'Remove-SqlOrphanUser'              = 'Remove-DbaDbOrphanUser'
            'Repair-DbaOrphanUser'              = 'Repair-DbaDbOrphanUser'
            'Repair-SqlOrphanUser'              = 'Repair-DbaDbOrphanUser'
            'Reset-SqlAdmin'                    = 'Reset-DbaAdmin'
            'Reset-SqlSaPassword'               = 'Reset-SqlAdmin'
            'Restart-DbaSqlService'             = 'Restart-DbaService'
            'Restore-DbaDatabaseCertificate'    = 'Restore-DbaDbCertificate'
            'Restore-DbaDatabaseSnapshot'       = 'Restore-DbaDbSnapshot'
            'Restore-HallengrenBackup'          = 'Restore-SqlBackupFromDirectory'
            'Set-DbaConfig'                     = 'Set-DbatoolsConfig'
            'Get-DbaBackupHistory'              = 'Get-DbaDbBackupHistory'
            'Set-DbaDatabaseOwner'              = 'Set-DbaDbOwner'
            'Set-DbaDatabaseState'              = 'Set-DbaDbState'
            'Set-DbaDbQueryStoreOptions'        = 'Set-DbaDbQueryStoreOption'
            'Set-DbaJobOwner'                   = 'Set-DbaAgentJobOwner'
            'Set-DbaQueryStoreConfig'           = 'Set-DbaDbQueryStoreOption'
            'Set-DbaTempDbConfiguration'        = 'Set-DbaTempdbConfig'
            'Set-SqlMaxMemory'                  = 'Set-DbaMaxMemory'
            'Set-SqlTempDbConfiguration'        = 'Set-DbaTempdbConfig'
            'Show-DbaDatabaseList'              = 'Show-DbaDbList'
            'Show-SqlDatabaseList'              = 'Show-DbaDbList'
            'Show-SqlMigrationConstraint'       = 'Test-SqlMigrationConstraint'
            'Show-SqlInstanceFileSystem'        = 'Show-DbaInstanceFileSystem'
            'Show-SqlWhoIsActive'               = 'Invoke-DbaWhoIsActive'
            'Start-DbaSqlService'               = 'Start-DbaService'
            'Start-SqlMigration'                = 'Start-DbaMigration'
            'Stop-DbaSqlService'                = 'Stop-DbaService'
            'Sync-DbaSqlLoginPermission'        = 'Sync-DbaLoginPermission'
            'Sync-SqlLoginPermissions'          = 'Sync-DbaLoginPermission'
            'Test-DbaDatabaseCollation'         = 'Test-DbaDbCollation'
            'Test-DbaDatabaseCompatibility'     = 'Test-DbaDbCompatibility'
            'Test-DbaDatabaseOwner'             = 'Test-DbaDbOwner'
            'Test-DbaDbVirtualLogFile'          = 'Measure-DbaDbVirtualLogFile'
            'Test-DbaFullRecoveryModel'         = 'Test-DbaDbRecoveryModel'
            'Test-DbaJobOwner'                  = 'Test-DbaAgentJobOwner'
            'Test-DbaLogShippingStatus'         = 'Test-DbaDbLogShipStatus'
            'Test-DbaRecoveryModel'             = 'Test-DbaDbRecoveryModel'
            'Test-DbaSqlBuild'                  = 'Test-DbaBuild'
            'Test-DbaSqlManagementObject'       = 'Test-DbaManagementObject'
            'Test-DbaSqlPath'                   = 'Test-DbaPath'
            'Test-DbaTempDbConfiguration'       = 'Test-DbaTempdbConfig'
            'Test-DbaValidLogin'                = 'Test-DbaWindowsLogin'
            'Test-DbaVirtualLogFile'            = 'Measure-DbaDbVirtualLogFile'
            'Test-SqlConnection'                = 'Test-DbaConnection'
            'Test-SqlDiskAllocation'            = 'Test-DbaDiskAllocation'
            'Test-SqlMigrationConstraint'       = 'Test-DbaMigrationConstraint'
            'Test-SqlNetworkLatency'            = 'Test-DbaNetworkLatency'
            'Test-SqlPath'                      = 'Test-DbaPath'
            'Test-SqlTempDbConfiguration'       = 'Test-DbaTempdbConfig'
            'Update-DbaSqlServiceAccount'       = 'Update-DbaServiceAccount'
            'Watch-DbaXEventSession'            = 'Watch-DbaXESession'
            'Watch-SqlDbLogin'                  = 'Watch-DbaDbLogin'
            'Add-DbaCmsRegServer'               = 'Add-DbaRegServer'
            'Add-DbaCmsRegServerGroup'          = 'Add-DbaRegServerGroup'
            'Copy-DbaCmsRegServer'              = 'Copy-DbaRegServer'
            'Export-DbaCmsRegServer'            = 'Export-DbaRegServer'
            'Get-DbaCmsRegistryRoot'            = 'Get-DbaRegistryRoot'
            'Get-DbaCmsRegServer'               = 'Get-DbaRegServer'
            'Get-DbaCmsRegServerGroup'          = 'Get-DbaRegServerGroup'
            'Get-DbaCmsRegServerStore'          = 'Get-DbaRegServerStore'
            'Import-DbaCmsRegServer'            = 'Import-DbaRegServer'
            'Move-DbaCmsRegServer'              = 'Move-DbaRegServer'
            'Move-DbaCmsRegServerGroup'         = 'Move-DbaRegServerGroup'
            'Remove-DbaCmsRegServer'            = 'Remove-DbaRegServer'
            'Remove-DbaCmsRegServerGroup'       = 'Remove-DbaRegServerGroup'
            'Copy-DbaServerAuditSpecification'  = 'Copy-DbaInstanceAuditSpecification'
            'Copy-DbaServerAudit'               = 'Copy-DbaInstanceAudit'
            'Copy-DbaServerTrigger'             = 'Copy-DbaInstanceTrigger'
            'Test-DbaServerName'                = 'Test-DbaInstanceName'
            'Test-DbaInstanceName'              = 'Repair-DbaInstanceName'
            'Get-DbaServerTrigger'              = 'Get-DbaInstanceTrigger'
            'Get-DbaServerAudit'                = 'Get-DbaInstanceAudit'
            'Get-DbaServerAuditSpecification'   = 'Get-DbaInstanceAuditSpecification'
            'Get-DbaServerInstallDate'          = 'Get-DbaInstanceInstallDate'
            'Show-DbaServerFileSystem'          = 'Show-DbaInstanceFileSystem'
            'Install-DbaWatchUpdate'            = 'Install-DbatoolsWatchUpdate'
            'Uninstall-DbaWatchUpdate'          = 'Uninstall-DbatoolsWatchUpdate'
        }
    }
    process {
        foreach ($fileobject in $InputObject) {
            $file = $fileobject.FullName

            foreach ($name in $paramrenames.GetEnumerator()) {
                if ((Select-String -Pattern $name.Key -Path $file)) {
                    if ($Pscmdlet.ShouldProcess($file, "Replacing $($name.Key) with $($name.Value)")) {
                        $content = (Get-Content -Path $file -Raw).Replace($name.Key, $name.Value).Trim()
                        Set-Content -Path $file -Encoding $Encoding -Value $content
                        [pscustomobject]@{
                            Path         = $file
                            Pattern      = $name.Key
                            ReplacedWith = $name.Value
                        }
                    }
                }
            }

            foreach ($name in $commandrenames.GetEnumerator()) {
                if ((Select-String -Pattern "\b$($name.Key)\b" -Path $file)) {
                    if ($Pscmdlet.ShouldProcess($file, "Replacing $($name.Key) with $($name.Value)")) {
                        $content = ((Get-Content -Path $file -Raw) -Replace "\b$($name.Key)\b", $name.Value).Trim()
                        Set-Content -Path $file -Encoding $Encoding -Value $content
                        [pscustomobject]@{
                            Path         = $file
                            Pattern      = $name.Key
                            ReplacedWith = $name.Value
                        }
                    }
                }
            }
        }
    }
}



# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAS0Zv9XwkU0km9
# H3BdFkM2qBe41LEO0lA8C8whhnue5aCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCB44o84Ewt/XqMRgfoHau9h5LLi
# NAgmAp7BD50q/9tpjDANBgkqhkiG9w0BAQEFAASCAQBGzUaAPBYyDeDhWwbk8b64
# APXp24PiBvDbLoJnrsPk//AEK12pmAmF0yYNpHyPLlGA76GRqftf27GlZjbPq6D/
# qpUz2HQAI2MnrDBPmYbRQLzsRw91VEel2VXSa6imGZkF9moyv52bTjbWtc479WmW
# Y3hg17uCyGrpkmWlkgbz5WUSkahGurR2TIRJ7iBqr20K6MPFEPCmPf3yn0A/6Jyz
# WUwR44/gr4Iij+tXUXQaPN6KRSBXlQliZIAqqk/Wtk6BZQ3BQ9PfSYgpqmfAlYrh
# Dq518wVC8/9ElJSCsfQV6f5QOXDLAC8Mpyd1s+sZmevYao27VF6jmTJsrj8/tpMO
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDYyN1owLwYJKoZIhvcNAQkEMSIE
# IBKRLmeqqNVh8ETHXxM+wcPLOO7C7X3E+zVHkEjsRCnEMA0GCSqGSIb3DQEBAQUA
# BIICAMfAnBR71zA3IsSSGv+vX0tTKzCu5GdcwfwDA/ZXUSL9DhSucxw8z1Tqpaqo
# QHcd7NRFSYxgrYT8IfhdwdByQxGf1q+l95BZYWHoh0Db+LHhc1PHjBRuLRqBQ2av
# DcMDZExYIcR6JQkAJiaD5Q+fp5QdTgeud7NRF/xTPLExKS5onj2AEYiWgX8SRbYy
# OxkD1W3zyZVWMB2/pPVjdRzKIOCqvE8uVM85EYEvpSqjaIW15ODXptAbz2A6u550
# +spc+VsUNb/8H7qcNjEasAFZsBbQBBd0XxHzSz9sNVCsECpXt2jLEHGt4lzOCges
# zBhjytQsFl/4BFKkwuyTMqwoQCvfwD2SGTa5X9Kkjd6JspNMMnyFSJvLepJONXHq
# wcAz+ICAOzWQFSlAoaB0iz06+DV6HF6iyV7kHhTPpMKZaAX2rjfqTvvpr2UgflpG
# 1Yqc9dUj/AtfZkA26WmcRnEaC/iJeKeC/HclrzeS+AuZR3E3lf+dMd/NyvwD9Fz2
# cEXUu4u0/hXqGNLtaqlYGGWCK48pJ7kUK1BrFmrlVybJVWHSJJWR5TIPhvik22Qt
# o4OED7F7R4GPWcXWPsPrJ21gPtRM9GLaCNnRS7axpBj0BtIR8cfgv13VmK3gnfAX
# Dx9+rjhxh9z5J2w8Z/HMa2N2+6ba72d4GI8cECP6oFeIKChW
# SIG # End signature block
