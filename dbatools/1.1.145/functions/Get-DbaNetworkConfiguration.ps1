function Get-DbaNetworkConfiguration {
    <#
    .SYNOPSIS
        Returns the network configuration of a SQL Server instance as shown in SQL Server Configuration Manager.

    .DESCRIPTION
        Returns a PowerShell object with the network configuration of a SQL Server instance as shown in SQL Server Configuration Manager.

        As we get information from SQL WMI and also from the registry, we use PS Remoting to run the core code on the target machine.

        For a detailed explanation of the different properties see the documentation at:
        https://docs.microsoft.com/en-us/sql/tools/configuration-manager/sql-server-network-configuration

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER Credential
        Credential object used to connect to the Computer as a different user.

    .PARAMETER OutputType
        Defines what information is returned from the command.
        Options include: Full, ServerProtocols, TcpIpProperties, TcpIpAddresses or Certificate. Full by default.

        Full returns one object per SqlInstance with information about the server protocols
        and nested objects with information about TCP/IP properties and TCP/IP addresses.
        It also outputs advanced properties including information about the used certificate.

        ServerProtocols returns one object per SqlInstance with information about the server protocols only.

        TcpIpProperties returns one object per SqlInstance with information about the TCP/IP protocol properties only.

        TcpIpAddresses returns one object per SqlInstance and IP address.
        If the instance listens on all IP addresses (TcpIpProperties.ListenAll), only the information about the IPAll address is returned.
        Otherwise only information about the individual IP addresses is returned.
        For more details see: https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port

        Certificate returns one object per SqlInstance with information about the configured network certificate and whether encryption is enforced.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Connection, SQLWMI
        Author: Andreas Jordan (@JordanOrdix), ordix.de

        Website: https://dbatools.io
        Copyright: (c) 2021 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaNetworkConfiguration

    .EXAMPLE
        PS C:\> Get-DbaNetworkConfiguration -SqlInstance sqlserver2014a

        Returns the network configuration for the default instance on sqlserver2014a.

    .EXAMPLE
        PS C:\> Get-DbaNetworkConfiguration -SqlInstance winserver\sqlexpress, sql2016 -OutputType ServerProtocols

        Returns information about the server protocols for the sqlexpress on winserver and the default instance on sql2016.

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$Credential,
        [ValidateSet('Full', 'ServerProtocols', 'TcpIpProperties', 'TcpIpAddresses', 'Certificate')]
        [string]$OutputType = 'Full',
        [switch]$EnableException
    )

    begin {
        $scriptBlock = {
            # This scriptblock will be processed by Invoke-Command2 on the target machine.
            # We take an object as the first parameter which has to include the properties ComputerName, InstanceName and SqlFullName,
            # so normally a DbaInstanceParameter.
            $instance = $args[0]
            $verbose = @( )

            # As we go remote, ensure the assembly is loaded
            [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')
            $wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
            $null = $wmi.Initialize()
            $wmiServerProtocols = ($wmi.ServerInstances | Where-Object { $_.Name -eq $instance.InstanceName } ).ServerProtocols

            $wmiSpSm = $wmiServerProtocols | Where-Object { $_.Name -eq 'Sm' }
            $wmiSpNp = $wmiServerProtocols | Where-Object { $_.Name -eq 'Np' }
            $wmiSpTcp = $wmiServerProtocols | Where-Object { $_.Name -eq 'Tcp' }

            $outputTcpIpProperties = [PSCustomObject]@{
                Enabled   = ($wmiSpTcp.ProtocolProperties | Where-Object { $_.Name -eq 'Enabled' } ).Value
                KeepAlive = ($wmiSpTcp.ProtocolProperties | Where-Object { $_.Name -eq 'KeepAlive' } ).Value
                ListenAll = ($wmiSpTcp.ProtocolProperties | Where-Object { $_.Name -eq 'ListenOnAllIPs' } ).Value
            }

            $wmiIPn = $wmiSpTcp.IPAddresses | Where-Object { $_.Name -ne 'IPAll' }
            $outputTcpIpAddressesIPn = foreach ($ip in $wmiIPn) {
                [PSCustomObject]@{
                    Name            = $ip.Name
                    Active          = ($ip.IPAddressProperties | Where-Object { $_.Name -eq 'Active' } ).Value
                    Enabled         = ($ip.IPAddressProperties | Where-Object { $_.Name -eq 'Enabled' } ).Value
                    IpAddress       = ($ip.IPAddressProperties | Where-Object { $_.Name -eq 'IpAddress' } ).Value
                    TcpDynamicPorts = ($ip.IPAddressProperties | Where-Object { $_.Name -eq 'TcpDynamicPorts' } ).Value
                    TcpPort         = ($ip.IPAddressProperties | Where-Object { $_.Name -eq 'TcpPort' } ).Value
                }
            }

            $wmiIPAll = $wmiSpTcp.IPAddresses | Where-Object { $_.Name -eq 'IPAll' }
            $outputTcpIpAddressesIPAll = [PSCustomObject]@{
                Name            = $wmiIPAll.Name
                TcpDynamicPorts = ($wmiIPAll.IPAddressProperties | Where-Object { $_.Name -eq 'TcpDynamicPorts' } ).Value
                TcpPort         = ($wmiIPAll.IPAddressProperties | Where-Object { $_.Name -eq 'TcpPort' } ).Value
            }

            $wmiService = $wmi.Services | Where-Object { $_.DisplayName -eq "SQL Server ($($instance.InstanceName))" }
            $serviceAccount = $wmiService.ServiceAccount
            $regRoot = ($wmiService.AdvancedProperties | Where-Object Name -eq REGROOT).Value
            $vsname = ($wmiService.AdvancedProperties | Where-Object Name -eq VSNAME).Value
            $verbose += "regRoot = '$regRoot' / vsname = '$vsname'"
            if ([System.String]::IsNullOrEmpty($regRoot)) {
                $regRoot = $wmiService.AdvancedProperties | Where-Object { $_ -match 'REGROOT' }
                $vsname = $wmiService.AdvancedProperties | Where-Object { $_ -match 'VSNAME' }
                $verbose += "regRoot = '$regRoot' / vsname = '$vsname'"
                if (![System.String]::IsNullOrEmpty($regRoot)) {
                    $regRoot = ($regRoot -Split 'Value\=')[1]
                    $vsname = ($vsname -Split 'Value\=')[1]
                    $verbose += "regRoot = '$regRoot' / vsname = '$vsname'"
                } else {
                    $verbose += "Can't find regRoot"
                }
            }
            if ($regRoot) {
                $regPath = "Registry::HKEY_LOCAL_MACHINE\$regRoot\MSSQLServer\SuperSocketNetLib"
                try {
                    $acceptedSPNs = (Get-ItemProperty -Path $regPath -Name AcceptedSPNs).AcceptedSPNs
                    $thumbprint = (Get-ItemProperty -Path $regPath -Name Certificate).Certificate
                    $cert = Get-ChildItem Cert:\LocalMachine -Recurse -ErrorAction SilentlyContinue | Where-Object Thumbprint -eq $thumbprint | Select-Object -First 1
                    $extendedProtection = switch ((Get-ItemProperty -Path $regPath -Name ExtendedProtection).ExtendedProtection) { 0 { $false } 1 { $true } }
                    $forceEncryption = switch ((Get-ItemProperty -Path $regPath -Name ForceEncryption).ForceEncryption) { 0 { $false } 1 { $true } }
                    $hideInstance = switch ((Get-ItemProperty -Path $regPath -Name HideInstance).HideInstance) { 0 { $false } 1 { $true } }

                    $outputCertificate = [PSCustomObject]@{
                        VSName          = $vsname
                        ServiceAccount  = $serviceAccount
                        ForceEncryption = $forceEncryption
                        FriendlyName    = $cert.FriendlyName
                        DnsNameList     = $cert.DnsNameList
                        Thumbprint      = $cert.Thumbprint
                        Generated       = $cert.NotBefore
                        Expires         = $cert.NotAfter
                        IssuedTo        = $cert.Subject
                        IssuedBy        = $cert.Issuer
                        Certificate     = $cert
                    }

                    $outputAdvanced = [PSCustomObject]@{
                        ForceEncryption    = $forceEncryption
                        HideInstance       = $hideInstance
                        AcceptedSPNs       = $acceptedSPNs
                        ExtendedProtection = $extendedProtection
                    }
                } catch {
                    $outputCertificate = $outputAdvanced = "Failed to get information from registry: $_"
                }
            } else {
                $outputCertificate = $outputAdvanced = "Failed to get information from registry: Path not found"
            }

            [PSCustomObject]@{
                ComputerName        = $instance.ComputerName
                InstanceName        = $instance.InstanceName
                SqlInstance         = $instance.SqlFullName.Trim('[]')
                SharedMemoryEnabled = $wmiSpSm.IsEnabled
                NamedPipesEnabled   = $wmiSpNp.IsEnabled
                TcpIpEnabled        = $wmiSpTcp.IsEnabled
                TcpIpProperties     = $outputTcpIpProperties
                TcpIpAddresses      = $outputTcpIpAddressesIPn + $outputTcpIpAddressesIPAll
                Certificate         = $outputCertificate
                Advanced            = $outputAdvanced
                Verbose             = $verbose
            }
        }
    }

    process {
        foreach ($instance in $SqlInstance) {
            try {
                $computerName = Resolve-DbaComputerName -ComputerName $instance.ComputerName -Credential $Credential
                $null = Test-ElevationRequirement -ComputerName $computerName -EnableException $true
                $netConf = Invoke-Command2 -ScriptBlock $scriptBlock -ArgumentList $instance -ComputerName $computerName -Credential $Credential -ErrorAction Stop
                foreach ($verbose in $netConf.Verbose) {
                    Write-Message -Level Verbose -Message $verbose
                }

                # Test if object is filled to test if instance was found on computer
                if ($null -eq $netConf.SharedMemoryEnabled) {
                    Stop-Function -Message "Failed to collect network configuration from $($instance.ComputerName) for instance $($instance.InstanceName). No data was found for this instance, so skipping." -Target $instance -ErrorRecord $_ -Continue
                }

                if ($OutputType -eq 'Full') {
                    [PSCustomObject]@{
                        ComputerName        = $netConf.ComputerName
                        InstanceName        = $netConf.InstanceName
                        SqlInstance         = $netConf.SqlInstance
                        SharedMemoryEnabled = $netConf.SharedMemoryEnabled
                        NamedPipesEnabled   = $netConf.NamedPipesEnabled
                        TcpIpEnabled        = $netConf.TcpIpEnabled
                        TcpIpProperties     = $netConf.TcpIpProperties
                        TcpIpAddresses      = $netConf.TcpIpAddresses
                        Certificate         = $netConf.Certificate
                        Advanced            = $netConf.Advanced
                    }
                } elseif ($OutputType -eq 'ServerProtocols') {
                    [PSCustomObject]@{
                        ComputerName        = $netConf.ComputerName
                        InstanceName        = $netConf.InstanceName
                        SqlInstance         = $netConf.SqlInstance
                        SharedMemoryEnabled = $netConf.SharedMemoryEnabled
                        NamedPipesEnabled   = $netConf.NamedPipesEnabled
                        TcpIpEnabled        = $netConf.TcpIpEnabled
                    }
                } elseif ($OutputType -eq 'TcpIpProperties') {
                    [PSCustomObject]@{
                        ComputerName = $netConf.ComputerName
                        InstanceName = $netConf.InstanceName
                        SqlInstance  = $netConf.SqlInstance
                        Enabled      = $netConf.TcpIpProperties.Enabled
                        KeepAlive    = $netConf.TcpIpProperties.KeepAlive
                        ListenAll    = $netConf.TcpIpProperties.ListenAll
                    }
                } elseif ($OutputType -eq 'TcpIpAddresses') {
                    if ($netConf.TcpIpProperties.ListenAll) {
                        $ipConf = $netConf.TcpIpAddresses | Where-Object { $_.Name -eq 'IPAll' }
                        [PSCustomObject]@{
                            ComputerName    = $netConf.ComputerName
                            InstanceName    = $netConf.InstanceName
                            SqlInstance     = $netConf.SqlInstance
                            Name            = $ipConf.Name
                            TcpDynamicPorts = $ipConf.TcpDynamicPorts
                            TcpPort         = $ipConf.TcpPort
                        }
                    } else {
                        $ipConf = $netConf.TcpIpAddresses | Where-Object { $_.Name -ne 'IPAll' }
                        foreach ($ip in $ipConf) {
                            [PSCustomObject]@{
                                ComputerName    = $netConf.ComputerName
                                InstanceName    = $netConf.InstanceName
                                SqlInstance     = $netConf.SqlInstance
                                Name            = $ip.Name
                                Active          = $ip.Active
                                Enabled         = $ip.Enabled
                                IpAddress       = $ip.IpAddress
                                TcpDynamicPorts = $ip.TcpDynamicPorts
                                TcpPort         = $ip.TcpPort
                            }
                        }
                    }
                } elseif ($OutputType -eq 'Certificate') {
                    if ($netConf.Certificate -like 'Failed*') {
                        Stop-Function -Message "Failed to collect certificate information from $($instance.ComputerName) for instance $($instance.InstanceName): $($netConf.Certificate)" -Target $instance -Continue
                    }
                    $output = [PSCustomObject]@{
                        ComputerName    = $netConf.ComputerName
                        InstanceName    = $netConf.InstanceName
                        SqlInstance     = $netConf.SqlInstance
                        VSName          = $netConf.Certificate.VSName
                        ServiceAccount  = $netConf.Certificate.ServiceAccount
                        ForceEncryption = $netConf.Certificate.ForceEncryption
                        FriendlyName    = $netConf.Certificate.FriendlyName
                        DnsNameList     = $netConf.Certificate.DnsNameList
                        Thumbprint      = $netConf.Certificate.Thumbprint
                        Generated       = $netConf.Certificate.Generated
                        Expires         = $netConf.Certificate.Expires
                        IssuedTo        = $netConf.Certificate.IssuedTo
                        IssuedBy        = $netConf.Certificate.IssuedBy
                        Certificate     = $netConf.Certificate.Certificate
                    }
                    $defaultView = 'ComputerName,InstanceName,SqlInstance,VSName,ServiceAccount,ForceEncryption,FriendlyName,DnsNameList,Thumbprint,Generated,Expires,IssuedTo,IssuedBy'.Split(',')
                    if (-not $netConf.Certificate.VSName) {
                        $defaultView = $defaultView | Where-Object { $_ -ne 'VSNAME' }
                    }
                    $output | Select-DefaultView -Property $defaultView
                }
            } catch {
                Stop-Function -Message "Failed to collect network configuration from $($instance.ComputerName) for instance $($instance.InstanceName)." -Target $instance -ErrorRecord $_ -Continue
            }
        }
    }
}



# SIG # Begin signature block
# MIIjYAYJKoZIhvcNAQcCoIIjUTCCI00CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCDwMTVxjkNCj+a
# I5pMHL6I0y7OU7cWPlAH9To5wlCJ9aCCHVkwggUaMIIEAqADAgECAhADBbuGIbCh
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
# BgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCAQ4AUc8hAn6/2JZqzpycSnvriK
# WcGzl0hHsZQzgqML/jANBgkqhkiG9w0BAQEFAASCAQBKMxJRcxwJevPnQOufnUvR
# oA2NEuJPkrLNuPM895jN41WjQjqofNqOul9y8K7boBKtC430INnNmW0wY5sTUHvY
# ll3tcKDCMeMSVljYhefj0azWKoeADzPzzXbCbOeTonNLpx93oefCHyYOIDkdEPkV
# 7hkPnJy8b+YHc8xk8JP2jDlL8cZKAaZv+Zrus43QTFKKX4xGWnz4+9z0bQMLq1iN
# P5TIY4NtKDdL3UIfhPmQwtQhCYAPKKpEFoXYGh/Uimi9sD+TCPbbbaSP9svrhFzF
# kAS+VAtDOFseMSUm9lhrVNAhgaJ/IRWYJVkj9AnYxzfqIO8+AVEgRYU6JF8fXJAY
# oYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwq
# Sj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDEyNzA3MDU1M1owLwYJKoZIhvcNAQkEMSIE
# IPZtTgJmAObvpVRnVKv3MMDmEBnk/dqLyRpSocHXtl50MA0GCSqGSIb3DQEBAQUA
# BIICAJMEXVeIY00NtjgON3ChbKb3WeY9Hz6OdKDrRRkdLPXy9Dp+sn3Afl/bsuXo
# pZjAza/aZTtnFYyhEL7qP1v+Jetn6qYNnStScnYGzfr4mZUqn+RFLWaFvSMPqaaj
# yUCP3k+XhU6YyXf2NVlerligtgyymmx37TVDIqQV7bFfTaI+HiwECJMNYebUMsJQ
# 0xz4IBMyxFKXEo+BWpXmMIrBbhJ47lLiQ2J1IMGm9Zu0TzfnKgf/fBCsulVYntRU
# mxho7kueeByP/5y06vsIRp3DQFcMGpNU7rijUDby/PZ8rSQaLaiDKebhiYaXbNVx
# NMMnmrrALWi9/R7lW6z7WtbbdW3djFnY2a5sO95lvOHx8rFVy7K7NqGfDroevFkq
# hbtHvgm1m5WRqGARzo/h3NEBL/SBJbb6B3+wmz+SgRNm/TmuzhBMshO9k6eReiPF
# rhL6RyV7c8buN1EG2Y52x25ySKqYSdL6+K4RsPAWWNDKQWXcEXrEFiLFwuTkhhxj
# mjbGoyGHLv6R/B01Z2at6ZvGaCL9p+jggkWkVTIdenP0XoOdNpsdK2kvgtipi71O
# yyRXnP/hmxmxXgp/3o0LIA8a8YLcqUdRcaaYKWw094SZZVBj2Ia0qb0GAHfLM3ce
# iE7UMQI6iesx+0cCjeuJy8XRhUnY1sSytU8hbmNJoxQvhx4U
# SIG # End signature block
