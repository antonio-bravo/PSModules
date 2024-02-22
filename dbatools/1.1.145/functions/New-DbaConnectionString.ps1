function New-DbaConnectionString {
    <#
    .SYNOPSIS
        Builds or extracts a SQL Server Connection String

    .DESCRIPTION
        Builds or extracts a SQL Server Connection String. Note that dbatools-style syntax is used.

        So you do not need to specify "Data Source", you can just specify -SqlInstance and -SqlCredential and we'll handle it for you.

        This is the simplified PowerShell approach to connection string building. See examples for more info.

        See https://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlconnection.connectionstring.aspx
        and https://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlconnectionstringbuilder.aspx
        and https://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlconnection.aspx

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER Credential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance. be it Windows or SQL Server. Windows users are determined by the existence of a backslash, so if you are intending to use an alternative Windows connection instead of a SQL login, ensure it contains a backslash.

    .PARAMETER AccessToken
        Basically tells the connection string to ignore authentication. Does not include the AccessToken in the resulting connecstring.

    .PARAMETER AppendConnectionString
        Appends to the current connection string. Note that you cannot pass authentication information using this method. Use -SqlInstance and, optionally, -SqlCredential to set authentication information.

    .PARAMETER ApplicationIntent
        Declares the application workload type when connecting to a server. Possible values are ReadOnly and ReadWrite.

    .PARAMETER BatchSeparator
        By default, this is "GO"

    .PARAMETER ClientName
        By default, this command sets the client's ApplicationName property to "dbatools PowerShell module - dbatools.io". If you're doing anything that requires profiling, you can look for this client name. Using -ClientName allows you to set your own custom client application name.

    .PARAMETER Database
        Database name

    .PARAMETER ConnectTimeout
        The length of time (in seconds) to wait for a connection to the server before terminating the attempt and generating an error.

        Valid values are greater than or equal to 0 and less than or equal to 2147483647.

        When opening a connection to a Azure SQL Database, set the connection timeout to 30 seconds.

    .PARAMETER EncryptConnection
        When true, SQL Server uses SSL encryption for all data sent between the client and server if the server has a certificate installed. Recognized values are true, false, yes, and no. For more information, see Connection String Syntax.

        Beginning in .NET Framework 4.5, when TrustServerCertificate is false and Encrypt is true, the server name (or IP address) in a SQL Server SSL certificate must exactly match the server name (or IP address) specified in the connection string. Otherwise, the connection attempt will fail. For information about support for certificates whose subject starts with a wildcard character (*), see Accepted wildcards used by server certificates for server authentication.

    .PARAMETER FailoverPartner
        The name of the failover partner server where database mirroring is configured.

        If the value of this key is "", then Initial Catalog must be present, and its value must not be "".

        The server name can be 128 characters or less.

        If you specify a failover partner but the failover partner server is not configured for database mirroring and the primary server (specified with the Server keyword) is not available, then the connection will fail.

        If you specify a failover partner and the primary server is not configured for database mirroring, the connection to the primary server (specified with the Server keyword) will succeed if the primary server is available.

    .PARAMETER IsActiveDirectoryUniversalAuth
        Azure related

    .PARAMETER LockTimeout
        Sets the time in seconds required for the connection to time out when the current transaction is locked.

    .PARAMETER MaxPoolSize
        Sets the maximum number of connections allowed in the connection pool for this specific connection string.

    .PARAMETER MinPoolSize
        Sets the minimum number of connections allowed in the connection pool for this specific connection string.

    .PARAMETER MultipleActiveResultSets
        When used, an application can maintain multiple active result sets (MARS). When false, an application must process or cancel all result sets from one batch before it can execute any other batch on that connection.

    .PARAMETER MultiSubnetFailover
        If your application is connecting to an AlwaysOn availability group (AG) on different subnets, setting MultiSubnetFailover provides faster detection of and connection to the (currently) active server. For more information about SqlClient support for Always On Availability Groups

    .PARAMETER NetworkProtocol
        Connect explicitly using 'TcpIp','NamedPipes','Multiprotocol','AppleTalk','BanyanVines','Via','SharedMemory' and 'NWLinkIpxSpx'

    .PARAMETER NonPooledConnection
        Request a non-pooled connection

    .PARAMETER PacketSize
        Sets the size in bytes of the network packets used to communicate with an instance of SQL Server. Must match at server.

    .PARAMETER PooledConnectionLifetime
        When a connection is returned to the pool, its creation time is compared with the current time, and the connection is destroyed if that time span (in seconds) exceeds the value specified by Connection Lifetime. This is useful in clustered configurations to force load balancing between a running server and a server just brought online.

        A value of zero (0) causes pooled connections to have the maximum connection timeout.

    .PARAMETER SqlExecutionModes
        The SqlExecutionModes enumeration contains values that are used to specify whether the commands sent to the referenced connection to the server are executed immediately or saved in a buffer.

        Valid values include CaptureSql, ExecuteAndCaptureSql and ExecuteSql.

    .PARAMETER StatementTimeout
        Sets the number of seconds a statement is given to run before failing with a time-out error.

    .PARAMETER TrustServerCertificate
        Sets a value that indicates whether the channel will be encrypted while bypassing walking the certificate chain to validate trust.

    .PARAMETER WorkstationId
        Sets the name of the workstation connecting to SQL Server.

    .PARAMETER Legacy
        Use this switch to create a connection string using System.Data.SqlClient instead of Microsoft.Data.SqlClient.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Tags: Connection, Connect, ConnectionString
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaConnectionString

    .EXAMPLE
        PS C:\> New-DbaConnectionString -SqlInstance sql2014

        Creates a connection string that connects using Windows Authentication

    .EXAMPLE
        PS C:\> Connect-DbaInstance -SqlInstance sql2016 | New-DbaConnectionString

        Builds a connected SMO object using Connect-DbaInstance then extracts and displays the connection string

    .EXAMPLE
        PS C:\> $wincred = Get-Credential ad\sqladmin
        PS C:\> New-DbaConnectionString -SqlInstance sql2014 -Credential $wincred

        Creates a connection string that connects using alternative Windows credentials

    .EXAMPLE
        PS C:\> $sqlcred = Get-Credential sqladmin
        PS C:\> $server = New-DbaConnectionString -SqlInstance sql2014 -Credential $sqlcred

        Login to sql2014 as SQL login sqladmin.

    .EXAMPLE
        PS C:\> $connstring = New-DbaConnectionString -SqlInstance mydb.database.windows.net -SqlCredential me@myad.onmicrosoft.com -Database db

        Creates a connection string for an Azure Active Directory login to Azure SQL db. Output looks like this:
        Data Source=TCP:mydb.database.windows.net,1433;Initial Catalog=db;User ID=me@myad.onmicrosoft.com;Password=fakepass;MultipleActiveResultSets=False;Connect Timeout=30;Encrypt=True;TrustServerCertificate=False;Application Name="dbatools PowerShell module - dbatools.io";Authentication="Active Directory Password"

    .EXAMPLE
        PS C:\> $server = New-DbaConnectionString -SqlInstance sql2014 -ClientName "mah connection"

        Creates a connection string that connects using Windows Authentication and uses the client name "mah connection". So when you open up profiler or use extended events, you can search for "mah connection".

    .EXAMPLE
        PS C:\> $server = New-DbaConnectionString -SqlInstance sql2014 -AppendConnectionString "Packet Size=4096;AttachDbFilename=C:\MyFolder\MyDataFile.mdf;User Instance=true;"

        Creates a connection string that connects to sql2014 using Windows Authentication, then it sets the packet size (this can also be done via -PacketSize) and other connection attributes.

    .EXAMPLE
        PS C:\> $server = New-DbaConnectionString -SqlInstance sql2014 -NetworkProtocol TcpIp -MultiSubnetFailover

        Creates a connection string with Windows Authentication that uses TCPIP and has MultiSubnetFailover enabled.

    .EXAMPLE
        PS C:\> $connstring = New-DbaConnectionString sql2016 -ApplicationIntent ReadOnly

        Creates a connection string with ReadOnly ApplicationIntent.

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias("ServerInstance", "SqlServer", "Server", "DataSource")]
        [DbaInstanceParameter[]]$SqlInstance,
        [Alias("SqlCredential")]
        [PSCredential]$Credential,
        [string]$AccessToken,
        [ValidateSet('ReadOnly', 'ReadWrite')]
        [string]$ApplicationIntent,
        [string]$BatchSeparator,
        [string]$ClientName = "custom connection",
        [int]$ConnectTimeout,
        [string]$Database,
        [switch]$EncryptConnection,
        [string]$FailoverPartner,
        [switch]$IsActiveDirectoryUniversalAuth,
        [int]$LockTimeout,
        [int]$MaxPoolSize,
        [int]$MinPoolSize,
        [switch]$MultipleActiveResultSets,
        [switch]$MultiSubnetFailover,
        [ValidateSet('TcpIp', 'NamedPipes', 'Multiprotocol', 'AppleTalk', 'BanyanVines', 'Via', 'SharedMemory', 'NWLinkIpxSpx')]
        [string]$NetworkProtocol,
        [switch]$NonPooledConnection,
        [int]$PacketSize,
        [int]$PooledConnectionLifetime,
        [ValidateSet('CaptureSql', 'ExecuteAndCaptureSql', 'ExecuteSql')]
        [string]$SqlExecutionModes,
        [int]$StatementTimeout,
        [switch]$TrustServerCertificate,
        [string]$WorkstationId,
        [switch]$Legacy,
        [string]$AppendConnectionString
    )
    begin {
        function Test-Azure {
            Param (
                [DbaInstanceParameter[]]$SqlInstance
            )
            if ($SqlInstance.ComputerName -match $AzureDomain) {
                Write-Message -Level Debug -Message "Test for Azure is positive"
                return $true
            } else {
                Write-Message -Level Debug -Message "Test for Azure is negative"
                return $false
            }
        }
    }
    process {
        foreach ($instance in $SqlInstance) {

            <#
            The new code path (formerly known as experimental) is now the default.
            To have a quick way to switch back in case any problems occur, the switch "legacy" is introduced: Set-DbatoolsConfig -FullName sql.connection.legacy -Value $true
            All the sub paths inside the following if clause will end with a continue, so the normal code path is not used.
            #>
            if (-not (Get-DbatoolsConfigValue -FullName sql.connection.legacy)) {
                <#
                Maybe more docs...
                #>
                Write-Message -Level Debug -Message "We have to build a connect string, using these parameters: $($PSBoundParameters.Keys)"

                # Test for unsupported parameters
                if (Test-Bound -ParameterName 'LockTimeout') {
                    Write-Message -Level Warning -Message "Parameter LockTimeout not supported, because it is not part of a connection string."
                }
                # TODO: That can be added to the Data Source - but why?
                #if (Test-Bound -ParameterName 'NetworkProtocol') {
                #    Write-Message -Level Warning -Message "Parameter NetworkProtocol not supported, because it is not part of a connection string."
                #}
                if (Test-Bound -ParameterName 'StatementTimeout') {
                    Write-Message -Level Warning -Message "Parameter StatementTimeout not supported, because it is not part of a connection string."
                }
                if (Test-Bound -ParameterName 'SqlExecutionModes') {
                    Write-Message -Level Warning -Message "Parameter SqlExecutionModes not supported, because it is not part of a connection string."
                }

                # Set defaults like in Connect-DbaInstance
                if (Test-Bound -Not -ParameterName 'Database') {
                    $Database = (Get-DbatoolsConfigValue -FullName 'sql.connection.database')
                }
                if (Test-Bound -Not -ParameterName 'ClientName') {
                    $ClientName = (Get-DbatoolsConfigValue -FullName 'sql.connection.clientname')
                }
                if (Test-Bound -Not -ParameterName 'ConnectTimeout') {
                    $ConnectTimeout = ([Sqlcollaborative.Dbatools.Connection.ConnectionHost]::SqlConnectionTimeout)
                }
                if (Test-Bound -Not -ParameterName 'EncryptConnection') {
                    $EncryptConnection = (Get-DbatoolsConfigValue -FullName 'sql.connection.encrypt')
                }
                if (Test-Bound -Not -ParameterName 'NetworkProtocol') {
                    $np = (Get-DbatoolsConfigValue -FullName 'sql.connection.protocol')
                    if ($np) {
                        $NetworkProtocol = $np
                    }
                }
                if (Test-Bound -Not -ParameterName 'PacketSize') {
                    $PacketSize = (Get-DbatoolsConfigValue -FullName 'sql.connection.packetsize')
                }
                if (Test-Bound -Not -ParameterName 'TrustServerCertificate') {
                    $TrustServerCertificate = (Get-DbatoolsConfigValue -FullName 'sql.connection.trustcert')
                }
                # TODO: Maybe put this in a config item:
                $AzureDomain = "database.windows.net"

                # Rename credential parameter to align with other commands, later rename parameter
                $SqlCredential = $Credential

                if ($Pscmdlet.ShouldProcess($instance, "Making a new Connection String")) {
                    if ($instance.Type -like "Server") {
                        Write-Message -Level Debug -Message "server object passed in, connection string is: $($instance.InputObject.ConnectionContext.ConnectionString)"
                        if ($Legacy) {
                            $converted = $instance.InputObject.ConnectionContext.ConnectionString | Convert-ConnectionString
                            $connStringBuilder = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $converted
                        } else {
                            $connStringBuilder = New-Object -TypeName Microsoft.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $instance.InputObject.ConnectionContext.ConnectionString
                        }
                        # In Azure, check for a database change
                        if ((Test-Azure -SqlInstance $instance) -and $Database) {
                            $connStringBuilder['Initial Catalog'] = $Database
                        }
                        $connstring = $connStringBuilder.ConnectionString
                        # TODO: Should we check the other parameters and change the connection string accordingly?
                    } else {
                        if ($Legacy) {
                            $connStringBuilder = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder
                        } else {
                            $connStringBuilder = New-Object -TypeName Microsoft.Data.SqlClient.SqlConnectionStringBuilder
                        }
                        $connStringBuilder['Data Source'] = $instance.FullSmoName
                        if ($ApplicationIntent) { $connStringBuilder['ApplicationIntent'] = $ApplicationIntent }
                        if ($ClientName) { $connStringBuilder['Application Name'] = $ClientName }
                        if ($ConnectTimeout) { $connStringBuilder['Connect Timeout'] = $ConnectTimeout }
                        if ($Database) { $connStringBuilder['Initial Catalog'] = $Database }
                        if ($EncryptConnection) { $connStringBuilder['Encrypt'] = $true } else { $connStringBuilder['Encrypt'] = $false }
                        if ($FailoverPartner) { $connStringBuilder['Failover Partner'] = $FailoverPartner }
                        if ($MaxPoolSize) { $connStringBuilder['Max Pool Size'] = $MaxPoolSize }
                        if ($MinPoolSize) { $connStringBuilder['Min Pool Size'] = $MinPoolSize }
                        if ($MultipleActiveResultSets) { $connStringBuilder['MultipleActiveResultSets'] = $true } else { $connStringBuilder['MultipleActiveResultSets'] = $false }
                        if ($MultiSubnetFailover) { $connStringBuilder['MultiSubnetFailover'] = $true }
                        if ($NonPooledConnection) { $connStringBuilder['Pooling'] = $false }
                        if ($PacketSize) { $connStringBuilder['Packet Size'] = $PacketSize }
                        if ($PooledConnectionLifetime) { $connStringBuilder['Load Balance Timeout'] = $PooledConnectionLifetime }
                        if ($TrustServerCertificate) { $connStringBuilder['TrustServerCertificate'] = $true } else { $connStringBuilder['TrustServerCertificate'] = $false }
                        if ($WorkstationId) { $connStringBuilder['Workstation Id'] = $WorkstationId }
                        if ($SqlCredential) {
                            Write-Message -Level Debug -Message "We have a SqlCredential"
                            $username = ($SqlCredential.UserName).TrimStart("\")
                            # support both ad\username and username@ad
                            if ($username -like "*\*") {
                                $domain, $login = $username.Split("\")
                                $username = "$login@$domain"
                            }
                            $connStringBuilder['User ID'] = $username
                            $connStringBuilder['Password'] = $SqlCredential.GetNetworkCredential().Password
                            if ((Test-Azure -SqlInstance $instance) -and ($username -like "*@*")) {
                                Write-Message -Level Debug -Message "We connect to Azure with Azure AD account, so adding Authentication=Active Directory Password"
                                $connStringBuilder['Authentication'] = 'Active Directory Password'
                            }
                        } else {
                            Write-Message -Level Debug -Message "We don't have a SqlCredential"
                            if (Test-Azure -SqlInstance $instance) {
                                Write-Message -Level Debug -Message "We connect to Azure, so adding Authentication=Active Directory Integrated"
                                $connStringBuilder['Authentication'] = 'Active Directory Integrated'
                            } else {
                                Write-Message -Level Debug -Message "We don't connect to Azure, so setting Integrated Security=True"
                                $connStringBuilder['Integrated Security'] = $true
                            }
                        }

                        # special config for Azure
                        if (Test-Azure -SqlInstance $instance) {
                            if (Test-Bound -Not -ParameterName ConnectTimeout) {
                                $connStringBuilder['Connect Timeout'] = 30
                            }
                            $connStringBuilder['Encrypt'] = $true
                            # Why adding tcp:?
                            #$connStringBuilder['Data Source'] = "tcp:$($instance.ComputerName),$($instance.Port)"
                        }
                        if ($Legacy) {
                            $connstring = $connStringBuilder.ConnectionString
                        } else {
                            $connstring = $connStringBuilder.ToString()
                        }
                        if ($AppendConnectionString) {
                            # TODO: Check if new connection string is still valid
                            $connstring = "$connstring;$AppendConnectionString"
                        }
                    }
                    $connstring
                    continue
                }
            }
            <#
            This is the end of the new default code path.
            All session with the configuration "sql.connection.legacy" set to $true will run through the following code.
            To use the legacy code path: Set-DbatoolsConfig -FullName sql.connection.legacy -Value $true
            #>

            Write-Message -Level Debug -Message "sql.connection.legacy is used"

            if ($Pscmdlet.ShouldProcess($instance, "Making a new Connection String")) {
                if ($instance.ComputerName -match "database\.windows\.net" -or $instance.InputObject.ComputerName -match "database\.windows\.net") {
                    if ($instance.InputObject.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
                        $connstring = $instance.InputObject.ConnectionContext.ConnectionString
                        if ($Database) {
                            $olddb = $connstring -split ';' | Where-Object { $_.StartsWith("Initial Catalog") }
                            $newdb = "Initial Catalog=$Database"
                            if ($olddb) {
                                $connstring = $connstring.Replace("$olddb", "$newdb")
                            } else {
                                $connstring = "$connstring;$newdb;"
                            }
                        }
                        $connstring
                        continue
                    } else {
                        $isAzure = $true

                        if (-not (Test-Bound -ParameterName ConnectTimeout)) {
                            $ConnectTimeout = 30
                        }

                        if (-not (Test-Bound -ParameterName ClientName)) {
                            $ClientName = "dbatools PowerShell module - dbatools.io"

                        }
                        $EncryptConnection = $true
                        $instance = [DbaInstanceParameter]"tcp:$($instance.ComputerName),$($instance.Port)"
                    }
                }

                if ($instance.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
                    return $instance.ConnectionContext.ConnectionString
                } else {
                    $guid = [System.Guid]::NewGuid()
                    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $guid

                    if ($AppendConnectionString) {
                        $connstring = $server.ConnectionContext.ConnectionString
                        $server.ConnectionContext.ConnectionString = "$connstring;$appendconnectionstring"
                        $server.ConnectionContext.ConnectionString
                    } else {

                        $server.ConnectionContext.ApplicationName = $ClientName
                        if ($BatchSeparator) { $server.ConnectionContext.BatchSeparator = $BatchSeparator }
                        if ($ConnectTimeout) { $server.ConnectionContext.ConnectTimeout = $ConnectTimeout }
                        if ($Database) { $server.ConnectionContext.DatabaseName = $Database }
                        if ($EncryptConnection) { $server.ConnectionContext.EncryptConnection = $true }
                        if ($IsActiveDirectoryUniversalAuth) { $server.ConnectionContext.IsActiveDirectoryUniversalAuth = $true }
                        if ($LockTimeout) { $server.ConnectionContext.LockTimeout = $LockTimeout }
                        if ($MaxPoolSize) { $server.ConnectionContext.MaxPoolSize = $MaxPoolSize }
                        if ($MinPoolSize) { $server.ConnectionContext.MinPoolSize = $MinPoolSize }
                        if ($MultipleActiveResultSets) { $server.ConnectionContext.MultipleActiveResultSets = $true }
                        if ($NetworkProtocol) { $server.ConnectionContext.NetworkProtocol = $NetworkProtocol }
                        if ($NonPooledConnection) { $server.ConnectionContext.NonPooledConnection = $true }
                        if ($PacketSize) { $server.ConnectionContext.PacketSize = $PacketSize }
                        if ($PooledConnectionLifetime) { $server.ConnectionContext.PooledConnectionLifetime = $PooledConnectionLifetime }
                        if ($StatementTimeout) { $server.ConnectionContext.StatementTimeout = $StatementTimeout }
                        if ($SqlExecutionModes) { $server.ConnectionContext.SqlExecutionModes = $SqlExecutionModes }
                        if ($TrustServerCertificate) { $server.ConnectionContext.TrustServerCertificate = $true }
                        if ($WorkstationId) { $server.ConnectionContext.WorkstationId = $WorkstationId }

                        if ($null -ne $Credential.username) {
                            $username = ($Credential.username).TrimStart("\")

                            if ($username -like "*\*") {
                                $username = $username.Split("\")[1]
                                $server.ConnectionContext.LoginSecure = $true
                                $server.ConnectionContext.ConnectAsUser = $true
                                $server.ConnectionContext.ConnectAsUserName = $username
                                $server.ConnectionContext.ConnectAsUserPassword = ($Credential).GetNetworkCredential().Password
                            } else {
                                $server.ConnectionContext.LoginSecure = $false
                                $server.ConnectionContext.set_Login($username)
                                $server.ConnectionContext.set_SecurePassword($Credential.Password)
                            }
                        }

                        $connstring = $server.ConnectionContext.ConnectionString
                        if ($MultiSubnetFailover) { $connstring = "$connstring;MultiSubnetFailover=True" }
                        if ($FailoverPartner) { $connstring = "$connstring;Failover Partner=$FailoverPartner" }
                        if ($ApplicationIntent) { $connstring = "$connstring;ApplicationIntent=$ApplicationIntent;" }

                        if ($isAzure) {
                            if ($Credential) {
                                if ($Credential.UserName -like "*\*" -or $Credential.UserName -like "*@*") {
                                    $connstring = "$connstring;Authentication=`"Active Directory Password`""
                                } else {
                                    $username = ($Credential.username).TrimStart("\")
                                    $server.ConnectionContext.LoginSecure = $false
                                    $server.ConnectionContext.set_Login($username)
                                    $server.ConnectionContext.set_SecurePassword($Credential.Password)
                                }
                            } else {
                                $connstring = $connstring.Replace("Integrated Security=True;", "Persist Security Info=True;")
                                if (-not $AccessToken) {
                                    $connstring = "$connstring;Authentication=`"Active Directory Integrated`""
                                }
                            }
                        }

                        if ($connstring -ne $server.ConnectionContext.ConnectionString) {
                            $server.ConnectionContext.ConnectionString = $connstring
                        }

                        ($server.ConnectionContext.ConnectionString).Replace($guid, $instance)
                    }
                }
            }
        }
    }
}


# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAuRsr8UIXLpMGy
# jcDi8/RKKMZCdwCZiNPEZu9BhbgMOqCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDehG1tFdiHBCgy9Wn5AnOVyzG6
# 8Mxrp6KkhDGw3SR7gTANBgkqhkiG9w0BAQEFAASCAQBieZR0aQpVy/vsh/CfXXZf
# ElsFtj0wflYUHa4BTXIPlTMtGSHuWX0RZCpwGlfVrQmiH968fgcXpru/XYm63wwb
# jiIj4b9YJ80QsnACEumqRGKTvGyG1JF/E21KOnV04Y2l6C79HrqGneIhYdPN3UWj
# xOF4aNS9WFQN+Y3rIMzZt+b0Zb+1CH5emPD3iMRwv1ZcjZx5xtG85rQI2KBdltYg
# nby4kwtn5Bi/wgQPxRWItMx/yuwA1u/8U+YIx+OdqMB0louBJW2o4v7I4/Rtjfmx
# Sq6NRb76nSkg0oY14n8SB2d+meYstkDpmO+Nd3v/DKb0hn12tBegvoOOB9SIqcil
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDYzNFowLwYJKoZIhvcNAQkEMSIE
# ICs6GafS5f3Sl1kBpR7DKUywHdP+ah79XgdHQIACE7t8MA0GCSqGSIb3DQEBAQUA
# BIICAAiXM9JV/Ft4gxhRmZzuE9/z9cluz6d69HzwYC/MQGvJ9NJtiHOq5NLlH2S9
# WS8SpGuY02TUohTZ16ru3yqFbm+Ilh2Tx6vtJeIbE+Ts1VOH7jxEXzAiI6TbBIUn
# gkd/YFMSNULZ1dwbf8OEBMyPEp6lNn6QhNGDQ1LOG0dU9PnEEmS+bLOegelgKJG9
# fWsGP+IW5ELcNlv983PGpyi7AzSGVWzml66nfWJb4cOp6f1UAsrSHqIfzLP3FJpu
# qXb/LzLNiQADnd7NzslM6k6kn/NCFxXDC8ONx45XZz7eEugQ6TRTp8V0Su4wX6M7
# v8u2LIKVOaHxd/Euc/WWv05fi6ulaN7rN+8TbksYvirUB7PVuyJV1BG7NTX8oLyM
# KQNjPKEd14CqB5D+bIBflybeDzAbLq72fj//o74hmCwHvvxkJLLwYJZV2XoFE7Fb
# ZilFlcCv7pxekBxOixUsdIWXJY5SAnXdafc7WtEKvSJ7xrBGWkF8YPn63qXwRtN4
# UqlM3GqMd8kJkscSBhRPertM5gpyrpS4dJQSoj97UoJhHZuDPlkCC1MlNK644b1+
# 89c4+cMGJA5cFG5ghyitIfFHHg2VP5nTwmsfqFu8+/Yu77vKXyhQrxPycgsLcd5H
# Veos7DNxOJbNBO44VupvOoOTbM1Cv8B0VKdhzyM5+MCgH+hF
# SIG # End signature block
