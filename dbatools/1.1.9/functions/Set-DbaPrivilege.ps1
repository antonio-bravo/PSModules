function Set-DbaPrivilege {
    <#
    .SYNOPSIS
        Adds the SQL Service account to local privileges on one or more computers.

    .DESCRIPTION
        Adds the SQL Service account to local privileges 'Lock Pages in Memory', 'Instant File Initialization', 'Logon as Batch' on one or more computers.

        Requires Local Admin rights on destination computer(s).

    .PARAMETER ComputerName
        The target SQL Server instance or instances.

    .PARAMETER Credential
        Credential object used to connect to the computer as a different user.

    .PARAMETER Type
        Use this to choose the privilege(s) to which you want to add the SQL Service account.
        Accepts 'IFI', 'LPIM', 'BatchLogon', and/or 'SecAudit' for local privileges 'Instant File Initialization', 'Lock Pages in Memory', 'Logon as Batch', and 'Generate Security Audits'.

    .PARAMETER User
        If provided, will add requested permissions to this account instead of the the account under which the SQL service is running.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Privilege
        Author: Klaas Vandenberghe ( @PowerDBAKlaas )

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Set-DbaPrivilege

    .EXAMPLE
        PS C:\> Set-DbaPrivilege -ComputerName sqlserver2014a -Type LPIM,IFI

        Adds the SQL Service account(s) on computer sqlserver2014a to the local privileges 'SeManageVolumePrivilege' and 'SeLockMemoryPrivilege'.

    .EXAMPLE
        PS C:\> 'sql1','sql2','sql3' | Set-DbaPrivilege -Type IFI

        Adds the SQL Service account(s) on computers sql1, sql2 and sql3 to the local privilege 'SeManageVolumePrivilege'.

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(ValueFromPipeline)]
        [Alias("cn", "host", "Server")]
        [dbainstanceparameter[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [Parameter(Mandatory)]
        [ValidateSet('IFI', 'LPIM', 'BatchLogon', 'SecAudit')]
        [string[]]$Type,
        [switch]$EnableException,
        [string]$User
    )

    begin {
        $ResolveAccountToSID = @"
function Convert-UserNameToSID ([string] `$Acc ) {
`$objUser = New-Object System.Security.Principal.NTAccount(`"`$Acc`")
`$strSID = `$objUser.Translate([System.Security.Principal.SecurityIdentifier])
`$strSID.Value
}
"@
        $ComputerName = $ComputerName.ComputerName | Select-Object -Unique
    }
    process {
        foreach ($computer in $ComputerName) {
            if ($Pscmdlet.ShouldProcess($computer, "Setting Privilege for SQL Service Account")) {
                try {
                    $null = Test-ElevationRequirement -ComputerName $Computer -Continue
                    if (Test-PSRemoting -ComputerName $Computer) {
                        Write-Message -Level Verbose -Message "Exporting Privileges on $Computer"
                        Invoke-Command2 -Raw -ComputerName $computer -Credential $Credential -ScriptBlock {
                            $temp = ([System.IO.Path]::GetTempPath()).TrimEnd(""); secedit /export /cfg $temp\secpolByDbatools.cfg > $NULL;
                        }

                        $SQLServiceAccounts = @();
                        if (Test-Bound 'User') {
                            $SQLServiceAccounts += $User;
                        } else {
                            Write-Message -Level Verbose -Message "Getting SQL Service Accounts on $computer"
                            $SQLServiceAccounts += (Get-DbaService -ComputerName $computer -Type Engine).StartName
                        }
                        if ($SQLServiceAccounts.count -ge 1) {
                            Write-Message -Level Verbose -Message "Setting Privileges on $Computer"
                            Invoke-Command2 -Raw -ComputerName $computer -Credential $Credential -Verbose -ArgumentList $ResolveAccountToSID, $SQLServiceAccounts, $Type -ScriptBlock {
                                [CmdletBinding()]
                                param ($ResolveAccountToSID,
                                    $SQLServiceAccounts,
                                    $Type
                                )
                                . ([ScriptBlock]::Create($ResolveAccountToSID))
                                $temp = ([System.IO.Path]::GetTempPath()).TrimEnd("");
                                $tempfile = "$temp\secpolByDbatools.cfg"
                                if ('BatchLogon' -in $Type) {
                                    $BLline = Get-Content $tempfile | Where-Object { $_ -match "SeBatchLogonRight" }
                                    ForEach ($acc in $SQLServiceAccounts) {
                                        $SID = Convert-UserNameToSID -Acc $acc;
                                        if (-not $BLline) {
                                            $BLline = "SeBatchLogonRight = *$SID"
                                            (Get-Content $tempfile) -replace "\[Privilege Rights\]", "[Privilege Rights]`n$BLline" |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Batch Logon Privileges on $env:ComputerName"
                                        } elseif ($BLline -notmatch $SID) {
                                            (Get-Content $tempfile) -replace "SeBatchLogonRight = ", "SeBatchLogonRight = *$SID," |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Batch Logon Privileges on $env:ComputerName"
                                        } else {
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "$acc already has Batch Logon Privilege on $env:ComputerName"
                                        }
                                    }
                                }
                                if ('IFI' -in $Type) {
                                    $IFIline = Get-Content $tempfile | Where-Object { $_ -match "SeManageVolumePrivilege" }
                                    ForEach ($acc in $SQLServiceAccounts) {
                                        $SID = Convert-UserNameToSID -Acc $acc;
                                        if (-not $IFIline) {
                                            $IFIline = "SeManageVolumePrivilege = *$SID"
                                            (Get-Content $tempfile) -replace "\[Privilege Rights\]", "[Privilege Rights]`n$IFIline" |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Instant File Initialization Privileges on $env:ComputerName"
                                        } elseif ($IFIline -notmatch $SID) {
                                            (Get-Content $tempfile) -replace "SeManageVolumePrivilege = ", "SeManageVolumePrivilege = *$SID," |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Instant File Initialization Privileges on $env:ComputerName"
                                        } else {
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "$acc already has Instant File Initialization Privilege on $env:ComputerName"
                                        }
                                    }
                                }
                                if ('LPIM' -in $Type) {
                                    $LPIMline = Get-Content $tempfile | Where-Object { $_ -match "SeLockMemoryPrivilege" }
                                    ForEach ($acc in $SQLServiceAccounts) {
                                        $SID = Convert-UserNameToSID -Acc $acc;
                                        if (-not $LPIMline) {
                                            $LPIMline = "SeLockMemoryPrivilege = *$SID"
                                            (Get-Content $tempfile) -replace "\[Privilege Rights\]", "[Privilege Rights]`n$LPIMline" |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Lock Pages in Memory Privileges on $env:ComputerName"
                                        } elseif ($LPIMline -notmatch $SID) {
                                            (Get-Content $tempfile) -replace "SeLockMemoryPrivilege = ", "SeLockMemoryPrivilege = *$SID," |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Lock Pages in Memory Privileges on $env:ComputerName"
                                        } else {
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "$acc already has Lock Pages in Memory Privilege on $env:ComputerName"
                                        }
                                    }
                                }
                                if ('SecAudit' -in $Type) {
                                    $Line = Get-Content $tempfile | Where-Object { $_ -match "SeAuditPrivilege" }
                                    ForEach ($acc in $SQLServiceAccounts) {
                                        $SID = Convert-UserNameToSID -Acc $acc;
                                        if (-not $Line) {
                                            $Line = "SeAuditPrivilege = *$SID"
                                            (Get-Content $tempfile) -replace "\[Privilege Rights\]", "[Privilege Rights]`n$Line" |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Security Log Privileges on $env:ComputerName"
                                        } elseif ($Line -notmatch $SID) {
                                            (Get-Content $tempfile) -replace "SeAuditPrivilege = ", "SeAuditPrivilege = *$SID," |
                                                Set-Content $tempfile
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "Added $acc to Write to Security Log Privileges on $env:ComputerName"
                                        } else {
                                            <# DO NOT use Write-Message as this is inside of a script block #>
                                            Write-Verbose "$acc already has Write To Security Audit Privilege on $env:ComputerName"
                                        }
                                    }
                                }
                                $null = secedit /configure /cfg $tempfile /db secedit.sdb /areas USER_RIGHTS /overwrite /quiet
                            } -ErrorAction SilentlyContinue
                            Write-Message -Level Verbose -Message "Removing secpol file on $computer"
                            Invoke-Command2 -Raw -ComputerName $computer -Credential $Credential -ScriptBlock { $temp = ([System.IO.Path]::GetTempPath()).TrimEnd(""); Remove-Item $temp\secpolByDbatools.cfg -Force > $NULL }
                        } else {
                            Write-Message -Level Warning -Message "No SQL Service Accounts found on $Computer"
                        }
                    } else {
                        Write-Message -Level Warning -Message "Failed to connect to $Computer"
                    }
                } catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_ -Target $computer -Continue
                }
            }
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyYhHhMX2TMFZywaCN7COtnOD
# bbWgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFDDBG6ndd+CQ/qC9n5dztvuoZpJGMA0GCSqGSIb3DQEBAQUABIIBAHqWj4yF
# Sj4+N9jhqx+2MvPz4GlZrDcvxqGw3/9bsDPC2ozNu3S+dYxnpzEsJt4/sm5sh7t4
# fLRu5yvKxMXCpe9xcZ69tvM5s1W8EFaI7kdbiIIiKTWuDEHtoGOAXAeLutMcSSmr
# ihYz0AD4oMnk6SCFhi/dzDTgTAxhOd9EqLTTe3ioEvAmVwi/u+Y1+DXgytpPGEHK
# V36rAVLVK9CQsQzZYsn3Yu1w3/BZ7feZfig84gAz6dAeo270Lu+4NLfDKp3JjGiO
# y+/qLd17c8mZaHLz4urUBE5NGaNoSvzr9vQ7pnkDZa6e4y7TWT8MYJw8stZ9xuzD
# WIdVSn8OfvKt0N+hggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDgwNTEwMDQ1NVowLwYJKoZIhvcNAQkEMSIEIIXVjwwdTCXbkD7NPupOsu8B5fRO
# XCOeYHXfzqNXXJH2MA0GCSqGSIb3DQEBAQUABIIBAHVyKzfsVEhQ0AzT5OYMCOxE
# SRL21yWNB+CH4mYvJb6FsS3L7XQGeELwnzfdLsKIiBMOfd/Bq0jO4GRAq6mjh1qS
# kELexfvYsOOtqPslashsIC5zaG9+YLocEY0gjCIvdemoZAQdUH3kVyHMhdYcPR4x
# 5GGdGTgEWgT5nzPPquIMJ6jn/b07e75LnepZNs6qSUCFqrxZkVxYQwhIvmt7hkRi
# 6xyCRI/fr2bAhSVU+IhImc8TSSQyL3SdIDfILG52wT4VC0hUj9oW8iSaGovFt0E8
# r8z4uCElw0mtUWBWfdOfhhsQIRsyqiOy7tBrPvzPWdKRD8L3aoVD/nF1tMi6a30=
# SIG # End signature block
