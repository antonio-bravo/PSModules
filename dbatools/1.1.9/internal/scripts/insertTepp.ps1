if ($ExecutionContext.SessionState.InvokeCommand.GetCommand('TabExpansionPlusPlus\Register-ArgumentCompleter','Function,Cmdlet')) {
    $script:TEPP = $true
} else {
    $script:TEPP = $false
}

$functions = $executionContext.SessionState.InvokeCommand.GetCommands('*-Dba*', 'Function', $true) -as [Management.Automation.FunctionInfo[]]
[Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::DbatoolsCommands = $functions
$names = $functions.Name

#region Automatic TEPP by parameter name
Register-DbaTeppArgumentCompleter -Command $names -Parameter Alert -Name Alert -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter AlertCategory -Name AlertCategory -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Audit -Name Audit -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter AuditSpecification -Name AuditSpecification -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter AvailabilityGroup -Name AvailabilityGroup -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter BackupDevice -Name BackupDevice -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ConfigName -Name ConfigName -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Credential -Name Credential -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter CredentialIdentity -Name Credential -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter CustomError -Name CustomError -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Database -Name Database -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Endpoint -Name Endpoint -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeAlert -Name Alert -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeAlertCategory -Name AlertCategory -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeAudit -Name Audit -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeAuditSpecification -Name AuditSpecification -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeAvailabilityGroup -Name AvailabilityGroup -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeBackupDevice -Name BackupDevice -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeConfigName -Name ConfigName -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeCredential -Name Credential -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeCredentialIdentity -Name Credential -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeCustomError -Name CustomError -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeDatabase -Name Database -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeEndpoint -Name Endpoint -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeGroup -Name Group -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeJob -Name Job -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeJobCategory -Name JobCategory -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeLinkedServer -Name LinkedServer -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeLogin -Name Login -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeMailAccount -Name MailAccount -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeMailProfile -Name MailProfile -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeMailServer -Name MailServer -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeOperator -Name Operator -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeProxyAccount -Name ProxyAccount -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeResourcePool -Name ResourcePool -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeSchedule -Name Schedule -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeServerTrigger -Name ServerTrigger -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeSession -Name Session -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ExcludeSnapshot -Name Snapshot -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Group -Name Group -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Job -Name Job -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter JobCategory -Name JobCategory -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter LinkedServer -Name LinkedServer -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Login -Name Login -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter MailAccount -Name MailAccount -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter MailProfile -Name MailProfile -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter MailServer -Name MailServer -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Operator -Name Operator -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ProxyAccount -Name ProxyAccount -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ResourcePool -Name ResourcePool -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Schedule -Name Schedule -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter ServerTrigger -Name ServerTrigger -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Session -Name Session -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter Snapshot -Name Snapshot -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter SqlInstance -Name SqlInstance -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter InstanceProperty -Name InstanceProperty -All
Register-DbaTeppArgumentCompleter -Command $names -Parameter PowerPlan -Name PowerPlan -All
#endregion Automatic TEPP by parameter name

#region Explicit TEPP
Register-DbaTeppArgumentCompleter -Command "Import-DbaCsv" -Parameter Delimiter -Name delimiter
Register-DbaTeppArgumentCompleter -Command "Find-DbaCommand" -Parameter Tag -Name tag
Register-DbaTeppArgumentCompleter -Command "Get-DbatoolsConfig", "Get-DbatoolsConfigValue", "Register-DbatoolsConfig", "Set-DbatoolsConfig" -Parameter FullName -Name config
Register-DbaTeppArgumentCompleter -Command "Get-DbatoolsConfig", "Register-DbatoolsConfig", "Set-DbatoolsConfig" -Parameter Module -Name configmodule
Register-DbaTeppArgumentCompleter -Command "Get-DbatoolsConfig", "Register-DbatoolsConfig", "Set-DbatoolsConfig" -Parameter Name -Name config_name
Register-DbaTeppArgumentCompleter -Command "Get-DbatoolsPath", "Set-DbatoolsPath" -Parameter Name -Name path
Register-DbaTeppArgumentCompleter -Command "Get-DbaProcess", "Stop-DbaProcess" -Parameter ExcludeSpid -Name processSpid
Register-DbaTeppArgumentCompleter -Command "Get-DbaProcess", "Stop-DbaProcess" -Parameter Hostname -Name processHostname
Register-DbaTeppArgumentCompleter -Command "Get-DbaProcess", "Stop-DbaProcess" -Parameter Program -Name processProgram
Register-DbaTeppArgumentCompleter -Command "Get-DbaProcess", "Stop-DbaProcess" -Parameter Spid -Name processSpid
Register-DbaTeppArgumentCompleter -Command "Import-DbaXESessionTemplate", "Get-DbaXESessionTemplate", "Export-DbaXESessionTemplate" -Parameter Template -Name xesessiontemplate
Register-DbaTeppArgumentCompleter -Command "Import-DbaPfDataCollectorSetTemplate", "Get-DbaPfDataCollectorSetTemplate", "Export-DbaPfDataCollectorSetTemplate"  -Parameter Template -Name perfmontemplate
Register-DbaTeppArgumentCompleter -Command "New-DbaAgentSchedule" -Parameter FrequencyInterval -Name newagentschedule
Register-DbaTeppArgumentCompleter -Command "Set-DbaAgentSchedule" -Parameter FrequencyInterval -Name setagentschedule
Register-DbaTeppArgumentCompleter -Command "Get-DbaSpConfigure", "Set-DbaSpConfigure" -Parameter Name -Name ConfigName
Register-DbaTeppArgumentCompleter -Command "Copy-DbaSpConfigure" -Parameter ConfigName -Name ConfigName
Register-DbaTeppArgumentCompleter -Command "Copy-DbaSpConfigure" -Parameter ExcludeConfigName -Name ConfigName
#endregion Explicit TEPP
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU86oMYfT90kgUCMASGzgecGcy
# koagghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFCh0wyXjR2Zn+sZy661froglNpkcMA0GCSqGSIb3DQEBAQUABIIBACqzh54O
# hVC40icTT3MfrQzinmPu/2dWSIlr3aBa5YdIRN4ByP6/wwZHBnVNofNSCA0lyBTb
# JEhF4JF+Vk+rmID30F1FoxIkHrpF/V+DCbE7Msw8VbxgCKhflgwFXuqkqhnq5U69
# yflBg2ifsEwlUXZd3N+ciw92HISMODR9VfuiD74xzOOr4Xgyoo6iApwmBe0ro4R8
# TAtgAZDWGwOHZqsiQ2ZEnR1hhZRH4PdDUUPmTgOVjv1mFjVm6ce2rF//EZVywz2P
# DX6ZHU/ndOtsKfeIN6uAP2qEhYy+uGkOyxya4C1XhXLw691kgU3zVSqj6rYTtnCW
# uYpaqvLB0nfAeNmhggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDgwNTEwMDUyNVowLwYJKoZIhvcNAQkEMSIEIG0vihQsuuS6lpbNl5fRC8c9ePuK
# Dt73aWS+NhCcXUoTMA0GCSqGSIb3DQEBAQUABIIBAFMYHsjQMORLPUrczLGqBUc/
# lsCU0dUhvc2cRTpPHgkqO892WZ7PxVp4ztSH8hvrUCSsvV+0cz9FSkdt361sAQJ9
# dwD4bCRq9MB7htb5PsRHmaCFkZ6RoPgAU1l/3IukPu4uDAwShbsuLdl6XYz4hLby
# 2WLW2GS3BUP9bC1XbVgjWuW/tGKQi7OeFhDLXc5O0iGtbZuhEoLzKfa3/YKO8c/V
# A3IsFODfg5pOdxfik9pE/9xBTsQUypZQLj9UCDmykXwFSGhcOpiRz/0R36v3+QKQ
# /olvuhG0Ga9uYyv9b7XgN9cU+6GfemUr2Jpm6nisoSxCYiNkk1ksHh6evmdLcNM=
# SIG # End signature block
