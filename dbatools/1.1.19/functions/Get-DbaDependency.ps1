function Get-DbaDependency {
    <#
    .SYNOPSIS
        Finds object dependencies and their relevant creation scripts.

    .DESCRIPTION
        This function recursively finds all objects that depends on the input.
        It will then retrieve rich information from them, including their creation scripts and the order in which it should be applied.

        By using the 'Parents' switch, the function will instead retrieve all items that the input depends on (including their creation scripts).

        For more details on dependency, see:
        https://technet.microsoft.com/en-us/library/ms345449(v=sql.105).aspx

    .PARAMETER InputObject
        The SMO object to parse

    .PARAMETER AllowSystemObjects
        Normally, system objects are ignored by this function as dependencies.
        This switch overrides that behavior.

    .PARAMETER Parents
        Causes the function to retrieve all objects that the input depends on, rather than retrieving everything that depends on the input.

    .PARAMETER IncludeSelf
        Includes the object whose dependencies are retrieves itself.
        Useful when exporting an entire logic structure in order to recreate it in another database.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Database, Dependent, Dependency, Object
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaDependency

    .EXAMPLE
        PS C:\> $table = (Get-DbaDatabase -SqlInstance sql2012 -Database Northwind).tables | Where-Object Name -eq Customers
        PS C:\> $table | Get-DbaDependency

        Returns everything that depends on the "Customers" table

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$InputObject,
        [switch]$AllowSystemObjects,
        [switch]$Parents,
        [switch]$IncludeSelf,
        [switch]$EnableException
    )

    begin {
        #region Utility functions

        function Read-Parent {
            [CmdletBinding()]
            param (
                $InputObject
            )
            $InputObject.Urn
            if ($InputObject.Parent -ne $null) {
                Read-Parent $InputObject.Parent
            }
        }

        function Get-DependencyTree {
            [CmdletBinding()]
            param (
                $Object,

                $Server,

                [bool]
                $AllowSystemObjects,

                [bool]
                $EnumParents,

                [string]
                $FunctionName
            )

            $scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter
            $options = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
            $options.DriAll = $true
            $options.AllowSystemObjects = $AllowSystemObjects
            $options.WithDependencies = $true
            $scripter.Options = $options
            $scripter.Server = $Server

            $urnCollection = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

            Write-Message -Level 5 -Message "Adding $Object which is a $($Object.urn.Type)" -FunctionName $FunctionName
            $urnCollection.Add([Microsoft.SqlServer.Management.Sdk.Sfc.Urn]$Object.urn)

            #now we set up an event listener go get progress reports
            $progressReportEventHandler = [Microsoft.SqlServer.Management.Smo.ProgressReportEventHandler] {
                $name = $_.Current.GetAttribute('Name');
                Write-Message -Level 5 -Message "Analysed $name" -FunctionName $FunctionName
            }
            $scripter.add_DiscoveryProgress($progressReportEventHandler)

            return $scripter.DiscoverDependencies($urnCollection, $EnumParents)
        }

        function Read-DependencyTree {
            [CmdletBinding()]
            param (
                [System.Object]
                $InputObject,

                [int]
                $Tier,

                [System.Object]
                $Parent,

                [bool]
                $EnumParents
            )

            Add-Member -Force -InputObject $InputObject -Name Parent -Value $Parent -MemberType NoteProperty
            if ($EnumParents) { Add-Member -Force -InputObject $InputObject -Name Tier -Value ($Tier * -1) -MemberType NoteProperty -PassThru }
            else { Add-Member -Force -InputObject $InputObject -Name Tier -Value $Tier -MemberType NoteProperty -PassThru }

            $circularReferenceCheck = Read-Parent -InputObject $Parent
            if ($Tier -gt 0 -and $circularReferenceCheck.Value -Contains $InputObject.Urn.Value) {
                Write-Message -Message "Circular Reference detected. $circularReferenceCheck" -Level Warning
                return # End dependency tree descension here.
            }

            if ($InputObject.HasChildNodes) { Read-DependencyTree -InputObject $InputObject.FirstChild -Tier ($Tier + 1) -Parent $InputObject -EnumParents $EnumParents }
            if ($InputObject.NextSibling) { Read-DependencyTree -InputObject $InputObject.NextSibling -Tier $Tier -Parent $Parent -EnumParents $EnumParents }
        }

        function Get-DependencyTreeNodeDetail {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline)]
                $SmoObject,

                $Server,

                $OriginalResource,

                [bool]
                $AllowSystemObjects
            )

            begin {
                $scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter
                $options = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
                $options.DriAll = $true
                $options.AllowSystemObjects = $AllowSystemObjects
                $options.WithDependencies = $true
                $scripter.Options = $options
                $scripter.Server = $Server

                $eol = [System.Environment]::NewLine
            }

            process {
                foreach ($Item in $SmoObject) {
                    $richobject = $Server.GetSmoObject($Item.urn)
                    $parent = $Server.GetSmoObject($Item.Parent.Urn)

                    $NewObject = New-Object Sqlcollaborative.Dbatools.Database.Dependency
                    $NewObject.ComputerName = $server.ComputerName
                    $NewObject.ServiceName = $server.ServiceName
                    $NewObject.SqlInstance = $server.DomainInstanceName
                    $NewObject.Dependent = $richobject.Name
                    $NewObject.Type = $Item.Urn.Type
                    $NewObject.Owner = $richobject.Owner
                    $NewObject.IsSchemaBound = $Item.IsSchemaBound
                    $NewObject.Parent = $parent.Name
                    $NewObject.ParentType = $parent.Urn.Type
                    $NewObject.Tier = $Item.Tier
                    $NewObject.Object = $richobject
                    $NewObject.Urn = $richobject.Urn
                    $NewObject.OriginalResource = $OriginalResource

                    $SQLscript = $scripter.EnumScriptWithList($richobject)

                    # I can't remember how to remove these options and their syntax is breaking stuff
                    $SQLscript = $SQLscript -replace "SET ANSI_NULLS ON", ""
                    $SQLscript = $SQLscript -replace "SET QUOTED_IDENTIFIER ON", ""
                    $NewObject.Script = "$SQLscript $($eol)go"

                    $NewObject
                }
            }
        }

        function Select-DependencyPrecedence {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline)]
                $Dependency
            )

            begin {
                $list = @()
            }
            process {
                foreach ($dep in $Dependency) {
                    # Killing the pipeline is generally a bad idea, but since we have to group and sort things, we have not really a choice
                    $list += $dep
                }
            }
            end {
                $list | Group-Object -Property Object, Tier | ForEach-Object { $_.Group | Sort-Object -Property Tier -Descending | Select-Object -First 1 } | Sort-Object Tier
            }
        }
        #endregion Utility functions
    }
    process {
        foreach ($Item in $InputObject) {
            Write-Message -Level Verbose -Message "Processing: $Item"
            if ($null -eq $Item.urn) {
                Stop-Function -Message "$Item is not a valid SMO object" -Category InvalidData -Continue -Target $Item
            }

            # Find the server object to pass on to the function
            $parent = $Item.parent

            do { $parent = $parent.parent }
            until (($parent.urn.type -eq "Server") -or (-not $parent))

            if (-not $parent) {
                Stop-Function -Message "Failed to find valid server object in input: $Item" -Category InvalidData -Continue -Target $Item
            }

            $server = $parent

            $tree = Get-DependencyTree -Object $Item -AllowSystemObjects $false -Server $server -FunctionName (Get-PSCallStack)[0].COmmand -EnumParents $Parents
            $limitCount = 2
            if ($IncludeSelf) { $limitCount = 1 }
            if ($tree.Count -lt $limitCount) {
                Write-Message -Message "No dependencies detected for $($Item)" -Level Important
                continue
            }

            if ($IncludeSelf) { $resolved = Read-DependencyTree -InputObject $tree.FirstChild -Tier 0 -Parent $tree.FirstChild -EnumParents $Parents }
            else { $resolved = Read-DependencyTree -InputObject $tree.FirstChild.FirstChild -Tier 1 -Parent $tree.FirstChild -EnumParents $Parents }
            $resolved | Get-DependencyTreeNodeDetail -Server $server -OriginalResource $Item -AllowSystemObjects $AllowSystemObjects | Select-DependencyPrecedence
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7mshSYlY65R9v+y9DjA7NUBP
# YtqgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFAaBGCakysvYc49CBhWtEdHnjqXuMA0GCSqGSIb3DQEBAQUABIIBAGDpQ2Uz
# q866mQwBKY6J+03XnyhAAUV6X4Tc8kqsnf1Jg576/qit631to6ZGV2ArtYilQmGR
# 5p9JEWn359rtKSTHRv59BXAJh/Vm8zsf7e7kGQBpBgriHRpTyEWqLLpPgnPBedK6
# KVQEkRER3WkyyLSFhjyY/QxKYwsADNpt4cbMwzjrGJ8tK09qrT4c3bhh8uWJZHoM
# 5yzNq8uPnaULUxfNfHH4POJEz0/sRc1eeWHoahZXyynqnyGkGJ76Vsr/fWcdIgVT
# iqdwNy56kVIy77E8V7VDjfzv9J/ILezbfqgr6WQ42Nhxs4E+Em38lFV7grNDvkVB
# nqtjTaghymaPi86hggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDkxODEyNDcxOFowLwYJKoZIhvcNAQkEMSIEIPkHCv82hfJiO7rv4LcuOeJOc84t
# MicnfeA/lFx+2PrZMA0GCSqGSIb3DQEBAQUABIIBALhd3/kLhqE+kxn7Y0yvrFCr
# YLrAxMrL34oF4xx2OH3E50Uyv/u14CQCdm57BlPBrP5GG4XUzBdllyyV+eNftBxv
# EhDqWdxw005uhiQkCi3NeMoT8rSc6wvssx86aSNPp8HV+MJqhCDp1zxckBYq9c6M
# rLc293fbhRd3k8JdkXYAdL+VlJYfW8g3s3xDChN9ZmykT7Jxnk6sbiNZE22JvzH2
# 00/whajXef7ea6LQtvxQvIWDy4Kr5QFHqtKtnwQeJiIls1rXrJ7f792DZd0m82xz
# VeNIRTPqQJKjhMPB4BUuQFjQHDZTBa3Nx6pKhJr1TOd1GKOj3JZOZd7STDr9+E0=
# SIG # End signature block
