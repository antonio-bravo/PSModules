function Find-DbaDbDuplicateIndex {
    <#
    .SYNOPSIS
        Find duplicate and overlapping indexes.

    .DESCRIPTION
        This command will help you to find duplicate and overlapping indexes on a database or a list of databases.

        On SQL Server 2008 and higher, the IsFiltered property will also be checked

        Only supports CLUSTERED and NONCLUSTERED indexes.

        Output:
        TableName
        IndexName
        KeyColumns
        IncludedColumns
        IndexSizeMB
        IndexType
        CompressionDescription (When 2008+)
        [RowCount]
        IsDisabled
        IsFiltered (When 2008+)

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Database
        The database(s) to process. Options for this list are auto-populated from the server. If unspecified, all databases will be processed.

    .PARAMETER IncludeOverlapping
        If this switch is enabled, indexes which are partially duplicated will be returned.

        Example: If the first key column is the same between two indexes, but one has included columns and the other not, this will be shown.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Index, Lookup
        Author: Claudio Silva (@ClaudioESSilva)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Find-DbaDbDuplicateIndex

    .EXAMPLE
        PS C:\> Find-DbaDbDuplicateIndex -SqlInstance sql2005

        Returns duplicate indexes found on sql2005

    .EXAMPLE
        PS C:\> Find-DbaDbDuplicateIndex -SqlInstance sql2017 -SqlCredential sqladmin

        Finds exact duplicate indexes on all user databases present on sql2017, using SQL authentication.

    .EXAMPLE
        PS C:\> Find-DbaDbDuplicateIndex -SqlInstance sql2017 -Database db1, db2

        Finds exact duplicate indexes on the db1 and db2 databases.

    .EXAMPLE
        PS C:\> Find-DbaDbDuplicateIndex -SqlInstance sql2017 -IncludeOverlapping

        Finds both duplicate and overlapping indexes on all user databases.

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [object[]]$Database,
        [switch]$IncludeOverlapping,
        [switch]$EnableException
    )

    begin {
        $exactDuplicateQuery2005 = "
            WITH CTE_IndexCols
            AS (
                SELECT i.[object_id]
                    ,i.index_id
                    ,OBJECT_SCHEMA_NAME(i.[object_id]) AS SchemaName
                    ,OBJECT_NAME(i.[object_id]) AS TableName
                    ,NAME AS IndexName
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 0
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS KeyColumns
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 1
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS IncludedColumns
                    ,i.[type_desc] AS IndexType
                    ,i.is_disabled AS IsDisabled
                    ,i.is_unique AS IsUnique
                FROM sys.indexes AS i
                WHERE i.index_id > 0 -- Exclude HEAPS
                    AND i.[type_desc] IN (
                        'CLUSTERED'
                        ,'NONCLUSTERED'
                        )
                    AND OBJECT_SCHEMA_NAME(i.[object_id]) <> 'sys'
                )
                ,CTE_IndexSpace
            AS (
                SELECT s.[object_id]
                    ,s.index_id
                    ,SUM(s.[used_page_count]) * 8 / 1024.0 AS IndexSizeMB
                    ,SUM(p.[rows]) AS [RowCount]
                FROM sys.dm_db_partition_stats AS s
                INNER JOIN sys.partitions p WITH (NOLOCK) ON s.[partition_id] = p.[partition_id]
                    AND s.[object_id] = p.[object_id]
                    AND s.index_id = p.index_id
                WHERE s.index_id > 0 -- Exclude HEAPS
                    AND OBJECT_SCHEMA_NAME(s.[object_id]) <> 'sys'
                GROUP BY s.[object_id]
                    ,s.index_id
                )
            SELECT DB_NAME() AS DatabaseName
                ,CI1.SchemaName + '.' + CI1.TableName AS 'TableName'
                ,CI1.IndexName
                ,CI1.KeyColumns
                ,CI1.IncludedColumns
                ,CI1.IndexType
                ,COALESCE(CSPC.IndexSizeMB,0) AS 'IndexSizeMB'
                ,COALESCE(CSPC.[RowCount],0) AS 'RowCount'
                ,CI1.IsDisabled
                ,CI1.IsUnique
            FROM CTE_IndexCols AS CI1
            LEFT JOIN CTE_IndexSpace AS CSPC ON CI1.[object_id] = CSPC.[object_id]
                AND CI1.index_id = CSPC.index_id
            WHERE EXISTS (
                    SELECT 1
                    FROM CTE_IndexCols CI2
                    WHERE CI1.SchemaName = CI2.SchemaName
                        AND CI1.TableName = CI2.TableName
                        AND CI1.KeyColumns = CI2.KeyColumns
                        AND CI1.IncludedColumns = CI2.IncludedColumns
                        AND CI1.IndexName <> CI2.IndexName
                    )"

        $overlappingQuery2005 = "
            WITH CTE_IndexCols
            AS (
                SELECT i.[object_id]
                    ,i.index_id
                    ,OBJECT_SCHEMA_NAME(i.[object_id]) AS SchemaName
                    ,OBJECT_NAME(i.[object_id]) AS TableName
                    ,NAME AS IndexName
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 0
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS KeyColumns
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 1
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS IncludedColumns
                    ,i.[type_desc] AS IndexType
                    ,i.is_disabled AS IsDisabled
                    ,i.is_unique AS IsUnique
                FROM sys.indexes AS i
                WHERE i.index_id > 0 -- Exclude HEAPS
                    AND i.[type_desc] IN (
                        'CLUSTERED'
                        ,'NONCLUSTERED'
                        )
                    AND OBJECT_SCHEMA_NAME(i.[object_id]) <> 'sys'
                )
                ,CTE_IndexSpace
            AS (
                SELECT s.[object_id]
                    ,s.index_id
                    ,SUM(s.[used_page_count]) * 8 / 1024.0 AS IndexSizeMB
                    ,SUM(p.[rows]) AS [RowCount]
                FROM sys.dm_db_partition_stats AS s
                INNER JOIN sys.partitions p WITH (NOLOCK) ON s.[partition_id] = p.[partition_id]
                    AND s.[object_id] = p.[object_id]
                    AND s.index_id = p.index_id
                WHERE s.index_id > 0 -- Exclude HEAPS
                    AND OBJECT_SCHEMA_NAME(s.[object_id]) <> 'sys'
                GROUP BY s.[object_id]
                    ,s.index_id
                )
            SELECT DB_NAME() AS DatabaseName
                ,CI1.SchemaName + '.' + CI1.TableName AS 'TableName'
                ,CI1.IndexName
                ,CI1.KeyColumns
                ,CI1.IncludedColumns
                ,CI1.IndexType
                ,COALESCE(CSPC.IndexSizeMB,0) AS 'IndexSizeMB'
                ,COALESCE(CSPC.[RowCount],0) AS 'RowCount'
                ,CI1.IsDisabled
                ,CI1.IsUnique
            FROM CTE_IndexCols AS CI1
            LEFT JOIN CTE_IndexSpace AS CSPC ON CI1.[object_id] = CSPC.[object_id]
                AND CI1.index_id = CSPC.index_id
            WHERE EXISTS (
                    SELECT 1
                    FROM CTE_IndexCols CI2
                    WHERE CI1.SchemaName = CI2.SchemaName
                        AND CI1.TableName = CI2.TableName
                        AND (
                            (
                                CI1.KeyColumns LIKE CI2.KeyColumns + '%'
                                AND SUBSTRING(CI1.KeyColumns, LEN(CI2.KeyColumns) + 1, 1) = ' '
                                )
                            OR (
                                CI2.KeyColumns LIKE CI1.KeyColumns + '%'
                                AND SUBSTRING(CI2.KeyColumns, LEN(CI1.KeyColumns) + 1, 1) = ' '
                                )
                            )
                        AND CI1.IndexName <> CI2.IndexName
                    )"

        # Support Compression 2008+
        $exactDuplicateQuery = "
            WITH CTE_IndexCols
            AS (
                SELECT i.[object_id]
                    ,i.index_id
                    ,OBJECT_SCHEMA_NAME(i.[object_id]) AS SchemaName
                    ,OBJECT_NAME(i.[object_id]) AS TableName
                    ,NAME AS IndexName
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 0
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS KeyColumns
                    ,ISNULL(STUFF((
                                SELECT ', ' + col.NAME + ' ' + CASE
                                        WHEN idxCol.is_descending_key = 1
                                            THEN 'DESC'
                                        ELSE 'ASC'
                                        END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                INNER JOIN sys.columns col ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                    AND i.index_id = idxCol.index_id
                                    AND idxCol.is_included_column = 1
                                ORDER BY idxCol.key_ordinal
                                FOR XML PATH('')
                                ), 1, 2, ''), '') AS IncludedColumns
                    ,i.[type_desc] AS IndexType
                    ,i.is_disabled AS IsDisabled
                    ,i.has_filter AS IsFiltered
                    ,i.is_unique AS IsUnique
                FROM sys.indexes AS i
                WHERE i.index_id > 0 -- Exclude HEAPS
                    AND i.[type_desc] IN (
                        'CLUSTERED'
                        ,'NONCLUSTERED'
                        )
                    AND OBJECT_SCHEMA_NAME(i.[object_id]) <> 'sys'
                )
                ,CTE_IndexSpace
            AS (
                SELECT s.[object_id]
                    ,s.index_id
                    ,SUM(s.[used_page_count]) * 8 / 1024.0 AS IndexSizeMB
                    ,SUM(p.[rows]) AS [RowCount]
                    ,p.data_compression_desc AS CompressionDescription
                FROM sys.dm_db_partition_stats AS s
                INNER JOIN sys.partitions p WITH (NOLOCK) ON s.[partition_id] = p.[partition_id]
                    AND s.[object_id] = p.[object_id]
                    AND s.index_id = p.index_id
                WHERE s.index_id > 0 -- Exclude HEAPS
                    AND OBJECT_SCHEMA_NAME(s.[object_id]) <> 'sys'
                GROUP BY s.[object_id]
                    ,s.index_id
                    ,p.data_compression_desc
                )
            SELECT DB_NAME() AS DatabaseName
                ,CI1.SchemaName + '.' + CI1.TableName AS 'TableName'
                ,CI1.IndexName
                ,CI1.KeyColumns
                ,CI1.IncludedColumns
                ,CI1.IndexType
                ,COALESCE(CSPC.IndexSizeMB,0) AS 'IndexSizeMB'
                ,COALESCE(CSPC.CompressionDescription, 'NONE') AS 'CompressionDescription'
                ,COALESCE(CSPC.[RowCount],0) AS 'RowCount'
                ,CI1.IsDisabled
                ,CI1.IsFiltered
                ,CI1.IsUnique
            FROM CTE_IndexCols AS CI1
            LEFT JOIN CTE_IndexSpace AS CSPC ON CI1.[object_id] = CSPC.[object_id]
                AND CI1.index_id = CSPC.index_id
            WHERE EXISTS (
                    SELECT 1
                    FROM CTE_IndexCols CI2
                    WHERE CI1.SchemaName = CI2.SchemaName
                        AND CI1.TableName = CI2.TableName
                        AND CI1.KeyColumns = CI2.KeyColumns
                        AND CI1.IncludedColumns = CI2.IncludedColumns
                        AND CI1.IsFiltered = CI2.IsFiltered
                        AND CI1.IndexName <> CI2.IndexName
                    )"

        $overlappingQuery = "
            WITH CTE_IndexCols AS
            (
                SELECT
                        i.[object_id]
                        ,i.index_id
                        ,OBJECT_SCHEMA_NAME(i.[object_id]) AS SchemaName
                        ,OBJECT_NAME(i.[object_id]) AS TableName
                        ,Name AS IndexName
                        ,ISNULL(STUFF((SELECT ', ' + col.NAME + ' ' + CASE
                                                                    WHEN idxCol.is_descending_key = 1 THEN 'DESC'
                                                                    ELSE 'ASC'
                                                                END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                    INNER JOIN sys.columns col
                                    ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                AND i.index_id = idxCol.index_id
                                AND idxCol.is_included_column = 0
                                ORDER BY idxCol.key_ordinal
                        FOR XML PATH('')), 1, 2, ''), '') AS KeyColumns
                        ,ISNULL(STUFF((SELECT ', ' + col.NAME + ' ' + CASE
                                                                    WHEN idxCol.is_descending_key = 1 THEN 'DESC'
                                                                    ELSE 'ASC'
                                                                END -- Include column order (ASC / DESC)
                                FROM sys.index_columns idxCol
                                    INNER JOIN sys.columns col
                                    ON idxCol.[object_id] = col.[object_id]
                                    AND idxCol.column_id = col.column_id
                                WHERE i.[object_id] = idxCol.[object_id]
                                AND i.index_id = idxCol.index_id
                                AND idxCol.is_included_column = 1
                                ORDER BY idxCol.key_ordinal
                        FOR XML PATH('')), 1, 2, ''), '') AS IncludedColumns
                        ,i.[type_desc] AS IndexType
                        ,i.is_disabled AS IsDisabled
                        ,i.has_filter AS IsFiltered
                        ,i.is_unique AS IsUnique
                FROM sys.indexes AS i
                WHERE i.index_id > 0 -- Exclude HEAPS
                AND i.[type_desc] IN ('CLUSTERED', 'NONCLUSTERED')
                AND OBJECT_SCHEMA_NAME(i.[object_id]) <> 'sys'
            ),
            CTE_IndexSpace AS
            (
            SELECT
                        s.[object_id]
                        ,s.index_id
                        ,SUM(s.[used_page_count]) * 8 / 1024.0 AS IndexSizeMB
                        ,SUM(p.[rows]) AS [RowCount]
                        ,p.data_compression_desc AS CompressionDescription
                FROM sys.dm_db_partition_stats AS s
                    INNER JOIN sys.partitions p WITH (NOLOCK)
                    ON s.[partition_id] = p.[partition_id]
                    AND s.[object_id] = p.[object_id]
                    AND s.index_id = p.index_id
                WHERE s.index_id > 0 -- Exclude HEAPS
                    AND OBJECT_SCHEMA_NAME(s.[object_id]) <> 'sys'
                GROUP BY s.[object_id], s.index_id, p.data_compression_desc
            )
            SELECT
                    DB_NAME() AS DatabaseName
                    ,CI1.SchemaName + '.' + CI1.TableName AS 'TableName'
                    ,CI1.IndexName
                    ,CI1.KeyColumns
                    ,CI1.IncludedColumns
                    ,CI1.IndexType
                    ,COALESCE(CSPC.IndexSizeMB,0) AS 'IndexSizeMB'
                    ,COALESCE(CSPC.CompressionDescription, 'NONE') AS 'CompressionDescription'
                    ,COALESCE(CSPC.[RowCount],0) AS 'RowCount'
                    ,CI1.IsDisabled
                    ,CI1.IsFiltered
                    ,CI1.IsUnique
            FROM CTE_IndexCols AS CI1
                LEFT JOIN CTE_IndexSpace AS CSPC
                ON CI1.[object_id] = CSPC.[object_id]
                AND CI1.index_id = CSPC.index_id
            WHERE EXISTS (SELECT 1
                            FROM CTE_IndexCols CI2
                        WHERE CI1.SchemaName = CI2.SchemaName
                            AND CI1.TableName = CI2.TableName
                            AND (
                                        (CI1.KeyColumns like CI2.KeyColumns + '%' and SUBSTRING(CI1.KeyColumns,LEN(CI2.KeyColumns)+1,1) = ' ')
                                    OR (CI2.KeyColumns like CI1.KeyColumns + '%' and SUBSTRING(CI2.KeyColumns,LEN(CI1.KeyColumns)+1,1) = ' ')
                                )
                            AND CI1.IsFiltered = CI2.IsFiltered
                            AND CI1.IndexName <> CI2.IndexName
                        )"
    }
    process {
        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ($database) {
                $databases = $server.Databases | Where-Object Name -in $database
            } else {
                $databases = $server.Databases | Where-Object IsAccessible -eq $true
            }

            foreach ($db in $databases) {
                try {
                    Write-Message -Level Verbose -Message "Getting indexes from database '$db'."

                    $query = if ($server.versionMajor -eq 9) {
                        if ($IncludeOverlapping) { $overlappingQuery2005 }
                        else { $exactDuplicateQuery2005 }
                    } else {
                        if ($IncludeOverlapping) { $overlappingQuery }
                        else { $exactDuplicateQuery }
                    }

                    $db.Query($query)

                } catch {
                    Stop-Function -Message "Query failure" -Target $db
                }
            }
        }
    }
}


# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAUjzSmrL3d9c4k
# 9Qh6ahaVwBeg8LuyFbQ+IcrIYDuT5aCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDIH/fhSar33Q9LTAF4GXO0D9vY
# yQM2q9C6MGLNcvtUDzANBgkqhkiG9w0BAQEFAASCAQCSFw27yXfFLkr4bkGZ5Cjn
# pDTyzqIvD6ePmDFczRCMga2okW1U0QKtPXneApscH3k0PGHxQ5ftiODu3Bbn6PxX
# O7YHDIgl1LEZVHbh4uZZ85xt3hR24WxBFOsJktq9xnrHnvSqFL6yiWc2rxUx611t
# BvlFrgpQveKyrTAFQIcrzz4swZ+f+t0ZO3zIURCjYPt1Ju0UrFpIKnuVst3QhbTF
# rEyOuuSQrERz8tQIc1WeADJOz0AXo9N5YHnys1DY3ehPUlAg1c68ainnNS8HF16g
# Ib3PlYYvbQnVXuS8XcgiQRumw44EzOriosUeYiDZSW9hM7JJTaPjgArHj9i1H9tY
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDUwOVowLwYJKoZIhvcNAQkEMSIE
# IIYZQxOyczG4HezecW9tm6rVdcedmf9huTyIA7eoryJWMA0GCSqGSIb3DQEBAQUA
# BIICAHYVPNaasSSS8txRmMAgzUl3Psf0SqYtm5JdymgXpgQskAujPJKVRT5zrRoh
# 5YinAe/p4fwhqowfX2qt/H7aTrmLilkVT7VtdxOFNXZAivaDU69ASlBgLhBmkn04
# ZecTeHyu3s72qhJDLkWKREKVJqLWl7rKBRR9BbJfucpsdr/eF+nzxPtEFuv8Aa9+
# e/Exy2Yh0GJ/0RdLW8WWgSFLilDGPC/00oSvgWuRMIvJmRDv9FVZ5ZdJ3PRRzjKE
# 1/vm0FiJ8j0Q0GgW2k6emaExdrwYP/13CZ0doBN+6HioENzCd+kuGhDYng6mI+nK
# LNzhHZTLp8yfao6DgQqO1RUke/BxMlCT3kpk+ilPAwl8VOQ5Klo7jqTcRocBsRVS
# NmFLubiOf8EQAqoaTMEgkrIRkr2ephsRaSccKmhlP1sGQpsl0/SPuZX58tdWlm9F
# X8qLTFtcjVWQSt417Gp+lvsYJ8xZlQCrpcHfiqYy0mBzmJgpGNlAXFhJeBwxAjqO
# 7VdmNy3tG34kK0fgrU+ULRT9AIOY5mybbo2ZfZdrywKeO9cOlAkB/M2mGB88/EYF
# sj/W58ooCkgbCanXXJmuQYZ97dPtav/Xm80SV8wqWf4vgoQGWs0Mi8WNR1WOXFcl
# 07FdgY12TrcJtV4Pa69BoiQNbbviR3P+vfCTviBQ+cI6rLQz
# SIG # End signature block
