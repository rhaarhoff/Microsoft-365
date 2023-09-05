<##################################################################################################
#
.SYNOPSIS 
    This script copies all the default system protection alerts and edits them to include an external recipient (monitored mailbox or ticketing system).

    You must have the latest Exchange Online Management Shell installed, and connect using:

    Connect-IPPSSession

    Reference:
    https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps


.NOTES
    FileName:    Copy-DefaultProtectionAlerts.ps1
    Author:      Alex Fields, ITProMentor.com
    Based on:    Kelvin Tegelaar, Cyberdrain.com
    Created:     February 2023
	Revised:     February 2023
    Version:     1.0
    

.EXAMPLE 
    .\Copy-DefaultProtectionAlerts.ps1 -AlertingEmail "alerts@contoso.com" 

#>
###################################################################################################


#region parameters
Param(
    [Parameter(Mandatory=$True)]
    [System.String]$AlertingEmail
)

#endregion



#region copy alerts 

    $ProtectionAlerts = Get-ProtectionAlert | Where-Object { $_.NotifyUser -eq "TenantAdmins" -and $_.disabled -eq $false }

    ForEach ($ProtectionAlert in $ProtectionAlerts) {
        $NewName = if ($ProtectionAlert.name.Length -gt 30) { "$($ProtectionAlert.name.substring(0,30)) - $($AlertingEmail)" } else { "$($ProtectionAlert.name) - $($AlertingEmail)" }
        $ExistingRule = Get-ProtectionAlert -id $NewName -ErrorAction "SilentlyContinue"
        if (!$ExistingRule) {
            $splat = @{
                name                = $NewName
                NotifyUser          = $AlertingEmail
                Operation           = $ProtectionAlert.Operation
                NotificationEnabled = $true
                Severity            = $ProtectionAlert.Severity
                Category            = $ProtectionAlert.Category
                Comment             = $ProtectionAlert.Comment
                threattype          = $ProtectionAlert.threattype
                AggregationType     = $ProtectionAlert.AggregationType
                Disabled            = $ProtectionAlert.Disabled
            }
            try {
              $null = New-ProtectionAlert @splat -ErrorAction Stop
            }
            catch {
                write-host "Could not create rule. Most likely no subscription available. Error: $($_.Exception.Message)"
            }
        }
        else {
            write-host "Rule exists, Moving on."
        }
    }



#endregion