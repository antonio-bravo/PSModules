﻿Set-PSFConfig -Module PSFramework -Name 'Utility.Size.Style' -Value ([PSFramework.Utility.SizeStyle]::Dynamic) -Initialize -Validation sizestyle -Handler { [PSFramework.Utility.UtilityHost]::SizeStyle = $args[0] } -Description "Controls how size objects are displayed by default. Generally, their string representation is calculated to be user friendly (dynamic), can be updated to 'plain' number or a specific size. Can be overriden on a per-object basis."
Set-PSFConfig -Module PSFramework -Name 'Utility.Size.Digits' -Value 2 -Initialize -Validation integer0to9 -Handler { [PSFramework.Utility.UtilityHost]::SizeDigits = $args[0] } -Description "How many digits are used when displaying a size object."