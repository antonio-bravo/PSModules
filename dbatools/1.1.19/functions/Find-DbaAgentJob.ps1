function Find-DbaAgentJob {
    <#
    .SYNOPSIS
        Find-DbaAgentJob finds agent jobs that fit certain search filters.

    .DESCRIPTION
        This command filters SQL Agent jobs giving the DBA a list of jobs that may need attention or could possibly be options for removal.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER JobName
        Filter agent jobs to only the name(s) you list.
        Supports regular expression (e.g. MyJob*) being passed in.

    .PARAMETER ExcludeJobName
        Allows you to enter an array of agent job names to ignore

    .PARAMETER StepName
        Filter based on StepName.
        Supports regular expression (e.g. MyJob*) being passed in.

    .PARAMETER LastUsed
        Find all jobs that haven't ran in the INT number of previous day(s)

    .PARAMETER IsDisabled
        Find all jobs that are disabled

    .PARAMETER IsFailed
        Find all jobs that have failed

    .PARAMETER IsNotScheduled
        Find all jobs with no schedule assigned

    .PARAMETER IsNoEmailNotification
        Find all jobs without email notification configured

    .PARAMETER Category
        Filter based on agent job categories

    .PARAMETER Owner
        Filter based on owner of the job/s

    .PARAMETER Since
        Datetime object used to narrow the results to a date

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Agent, Job
        Author: Stephen Bennett (https://sqlnotesfromtheunderground.wordpress.com/)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Find-DbaAgentJob

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01 -JobName *backup*

        Returns all agent job(s) that have backup in the name

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01, Dev02 -JobName Mybackup

        Returns all agent job(s) that are named exactly Mybackup

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01 -LastUsed 10

        Returns all agent job(s) that have not ran in 10 days

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01 -IsDisabled -IsNoEmailNotification -IsNotScheduled

        Returns all agent job(s) that are either disabled, have no email notification or don't have a schedule. returned with detail

    .EXAMPLE
        PS C:\> $servers | Find-DbaAgentJob -IsFailed | Start-DbaAgentJob

        Finds all failed job then starts them. Consider using a -WhatIf at the end of Start-DbaAgentJob to see what it'll do first

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01 -LastUsed 10 -Exclude "Yearly - RollUp Workload", "SMS - Notification"

        Returns all agent jobs that have not ran in the last 10 days ignoring jobs "Yearly - RollUp Workload" and "SMS - Notification"

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01 -Category "REPL-Distribution", "REPL-Snapshot" | Format-Table -AutoSize -Wrap

        Returns all job/s on Dev01 that are in either category "REPL-Distribution" or "REPL-Snapshot"

    .EXAMPLE
        PS C:\> Find-DbaAgentJob -SqlInstance Dev01, Dev02 -IsFailed -Since '2016-07-01 10:47:00'

        Returns all agent job(s) on Dev01 and Dev02 that have failed since July of 2016 (and still have history in msdb)

    .EXAMPLE
        PS C:\> Get-DbaRegServer -SqlInstance CMSServer -Group Production | Find-DbaAgentJob -Disabled -IsNotScheduled | Format-Table -AutoSize -Wrap

        Queries CMS server to return all SQL instances in the Production folder and then list out all agent jobs that have either been disabled or have no schedule.

    .EXAMPLE
        $Instances = 'SQL2017N5','SQL2019N5','SQL2019N20','SQL2019N21','SQL2019N22'
        Find-DbaAgentJob -SqlInstance $Instances -JobName *backup* -IsNotScheduled

        Returns all agent job(s) wiht backup in the name, that don't have a schedule on 'SQL2017N5','SQL2019N5','SQL2019N20','SQL2019N21','SQL2019N22'
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]
        $SqlCredential,
        [Alias("Name")]
        [string[]]$JobName,
        [string[]]$ExcludeJobName,
        [string[]]$StepName,
        [int]$LastUsed,
        [Alias("Disabled")]
        [switch]$IsDisabled,
        [Alias("Failed")]
        [switch]$IsFailed,
        [Alias("NoSchedule")]
        [switch]$IsNotScheduled,
        [Alias("NoEmailNotification")]
        [switch]$IsNoEmailNotification,
        [string[]]$Category,
        [string]$Owner,
        [datetime]$Since,
        [switch]$EnableException
    )
    begin {
        if ($IsFailed, [boolean]$JobName, [boolean]$StepName, [boolean]$LastUsed.ToString(), $IsDisabled, $IsNotScheduled, $IsNoEmailNotification, [boolean]$Category, [boolean]$Owner, [boolean]$ExcludeJobName -notcontains $true) {
            Stop-Function -Message "At least one search term must be specified"
        }
    }
    process {
        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Running Scan on: $instance"

            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $output = @()

            if ($JobName) {
                Write-Message -Level Verbose -Message "Retrieving jobs by their name."
                $jobs = Get-JobList -SqlInstance $server -JobFilter $JobName
                $output = $jobs
            }

            if ($StepName) {
                Write-Message -Level Verbose -Message "Retrieving jobs by their step names."
                $jobs = Get-JobList -SqlInstance $server -StepFilter $StepName
                $output = $jobs
            }

            if ( -not ($JobName -or $StepName)) {
                Write-Message -Level Verbose -Message "Retrieving all jobs"
                $jobs = Get-JobList -SqlInstance $server
                $output = $jobs
            }

            if ($Category) {
                Write-Message -Level Verbose -Message "Finding job/s that have the specified category defined"
                $output = $jobs | Where-Object { $Category -contains $_.Category }
            }

            if ($IsFailed) {
                Write-Message -Level Verbose -Message "Checking for failed jobs."
                $output = $jobs | Where-Object LastRunOutcome -eq "Failed"
            }

            if ($LastUsed) {
                $DaysBack = $LastUsed * -1
                $SinceDate = (Get-Date).AddDays($DaysBack)
                Write-Message -Level Verbose -Message "Finding job/s not ran in last $LastUsed days"
                $output = $jobs | Where-Object { $_.LastRunDate -le $SinceDate }
            }

            if ($IsDisabled) {
                Write-Message -Level Verbose -Message "Finding job/s that are disabled"
                $output = $jobs | Where-Object IsEnabled -eq $false
            }

            if ($IsNotScheduled) {
                Write-Message -Level Verbose -Message "Finding job/s that have no schedule defined"
                $output = $jobs | Where-Object HasSchedule -eq $false
            }
            if ($IsNoEmailNotification) {
                Write-Message -Level Verbose -Message "Finding job/s that have no email operator defined"
                $output = $jobs | Where-Object { [string]::IsNullOrEmpty($_.OperatorToEmail) -eq $true }
            }

            if ($Owner) {
                Write-Message -Level Verbose -Message "Finding job/s with owner critera"
                if ($Owner -match "-") {
                    $OwnerMatch = $Owner -replace "-", ""
                    Write-Message -Level Verbose -Message "Checking for jobs that NOT owned by: $OwnerMatch"
                    $output = $jobs | Where-Object { $OwnerMatch -notcontains $_.OwnerLoginName }
                } else {
                    Write-Message -Level Verbose -Message "Checking for jobs that are owned by: $owner"
                    $output = $jobs | Where-Object { $Owner -contains $_.OwnerLoginName }
                }
            }

            if ($Exclude) {
                Write-Message -Level Verbose -Message "Excluding job/s based on Exclude"
                $output = $output | Where-Object { $Exclude -notcontains $_.Name }
            }

            if ($Since) {
                #$Since = $Since.ToString("yyyy-MM-dd HH:mm:ss")
                Write-Message -Level Verbose -Message "Getting only jobs whose LastRunDate is greater than or equal to $since"
                $output = $output | Where-Object { $_.LastRunDate -ge $since }
            }

            $jobs = $output | Select-Object -Unique

            foreach ($job in $jobs) {
                Add-Member -Force -InputObject $job -MemberType NoteProperty -Name ComputerName -value $server.ComputerName
                Add-Member -Force -InputObject $job -MemberType NoteProperty -Name InstanceName -value $server.ServiceName
                Add-Member -Force -InputObject $job -MemberType NoteProperty -Name SqlInstance -value $server.DomainInstanceName
                Add-Member -Force -InputObject $job -MemberType NoteProperty -Name JobName -value $job.Name


                Select-DefaultView -InputObject $job -Property ComputerName, InstanceName, SqlInstance, Name, Category, OwnerLoginName, CurrentRunStatus, CurrentRunRetryAttempt, 'IsEnabled as Enabled', LastRunDate, LastRunOutcome, DateCreated, HasSchedule, OperatorToEmail, 'DateCreated as CreateDate'
            }
        }
    }
}
# SIG # Begin signature block
# MIIZewYJKoZIhvcNAQcCoIIZbDCCGWgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUevO8yLtTPokfPcumV6ExDd6D
# NBCgghSJMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
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
# MRYEFPt7fd5ceT5Zr5lCASYBn36NYRnMMA0GCSqGSIb3DQEBAQUABIIBACR33GFh
# sXRWpdb20+kfAgH4If42hDdx5Mle+U+bCqFZy5UVL19zmYFlLB6e9Qi2+ZU/02J2
# 774nPhrSOZvQFGe9miy28BqmnfTQ07E8FPeU2v7A1L4IHFnpAZC45xA/Qv9OWhuB
# jro4DLd1vXPdc+gPdPzmfHp2mK6IIgA43WOg8E+MDhIglXvJOqZrHc5bvpOZmuh7
# ps0ElclpZ6s3lyu49jV5greMjjUjSa6PVTL4h6h+EEpLmgI2qCi6TBxaPBf9ZoAS
# qCoibbD+1WKAlbOTDJNoUQ9sApKDM50N7JCuaTaAtkMpRtGySU5w28C+57uf1kEm
# yNR7zK2dwwECszGhggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEF
# AKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIx
# MDkxODEyNDcwNVowLwYJKoZIhvcNAQkEMSIEIPSoiUJbcm5utKXjudUwU3KMJeVC
# b4HW1WI5ZI7+sAYbMA0GCSqGSIb3DQEBAQUABIIBAIkbLVZi8c8n8q5MUe5ehGt9
# IdcUoyuMVGv+HkkoSERvS+7WMfNYpFi5deZPBjUckYXaltjsFsOeOWZ5GQKb+OLq
# e9p6kF9Rh8XyT1bZjV1aGXKjbo/Ea5EItUvmQrWC+JJOYL4ep+G06u/WWBo0DppA
# gq8h1ssBQfknLxiFe9TBRXBDFA5tU4VBXm7S1KHF2ucmbuLOCy6xYKIXHHXPViD0
# zQCw27lPRKlvIB+l6jI3y4TmqcZ6QtnWnwVi//xOQ2P3qvTWykK8d4MSAL6Eke7N
# +eSU/rm8oWGyA+11NZGjz9x9ERI3znbBmBTbiu5ODRTKMc/Fnm9ttIUC5vhNfyY=
# SIG # End signature block
