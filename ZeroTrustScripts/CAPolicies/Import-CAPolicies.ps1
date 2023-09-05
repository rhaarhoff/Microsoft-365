<#    
.SYNOPSIS
    Script for automatic creation and update of Conditoinal Access Policies based on JSON representations

.DESCRIPTION
    Connects to Microsoft Graph

    Creates AAD group for AAD emergency access accounts
    Imports JSON representations of conditional access policies from a policy folder
    Either creates a new conditional access policy for each JSON representation or updates an existing policy. Updating / matching existing policies requires the policy id in the JSON file.

.PARAMETER PoliciesFolder
    Path of the folder where the templates are located e.g. C:\Temp\CAPolicies\Baseline

.PARAMETER EmergencyAccessGroup
    Name of the group for the emergency access accounts which are excluded from policies
    If no value is provided: "sg_EmergencyAccess"
    If a group with that name already exists, it will be used

.PARAMETER Endpoint
    Allows you to specify the Graph endpoint (Beta or Canary), if not specified it will default to Beta

.NOTES
    Version:        1.0
    Author:         Alex Fields
    Based on:       Alexander Filipin
    Last modified:  2023-02

    Many thanks to the Microsoft MVPs whose publications served as a basis for this script:
        Alexander Filipin: https://github.com/AlexFilipin/ConditionalAccess/blob/master/Deploy-Policies.ps1
        Jan Vidar Elven's work https://github.com/JanVidarElven/MicrosoftGraph-ConditionalAccess
        Daniel Chronlund's work https://danielchronlund.com/2019/11/07/automatic-deployment-of-conditional-access-with-powershell-and-microsoft-graph/
  
.EXAMPLE 
    .\Import-CAPolicies.ps1 -PoliciesFolder "C:\Temp\CAPolicies\Baseline" 

.EXAMPLE
    .\Import-CAPolicies.ps1 -PoliciesFolder "C:\Temp\CAPolicies\Baseline" -EmergencyAccessGroup "sg_BreakGlassAccounts"
#>
Param(
    [Parameter(Mandatory=$True)]
    [System.String]$PoliciesFolder
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$EmergencyAccessGroup
    ,
    [Parameter(Mandatory=$False)]
    [System.String]$Endpoint
)
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Groups

#region connect
Import-Module -Name Microsoft.Graph.Authentication
Import-Module -Name Microsoft.Graph.Groups
Import-Module -Name Microsoft.Graph.Identity.SignIns

if($Endpoint -eq "Beta"){
    Select-MgProfile -Name "beta"
}elseif($Endpoint -eq "V1"){
    Select-MgProfile -Name "v1.0"
}else{
    Select-MgProfile -Name "beta"
}
try{Disconnect-MgGraph -ErrorAction SilentlyContinue}catch{}
Connect-MgGraph -Scopes "Application.Read.All","Group.ReadWrite.All","Policy.Read.All","Policy.ReadWrite.ConditionalAccess" -ErrorAction Stop
#endregion

#region parameters
if(-not $EmergencyAccessGroup){$EmergencyAccessGroup = "sg_EmergencyAccess"}
#endregion

#region functions
function New-AFAzureADGroup($Name){
    $Group = Get-MgGroup -Filter "DisplayName eq '$Name'"
    if(-not $Group){
        Write-Host "Creating group: $Name"
        $Group = New-MgGroup -DisplayName $Name -SecurityEnabled:$true -MailEnabled:$false -MailNickname "NotSet"
    }
    Write-Host "ObjectId for $Name $($Group.Id)" 
    return $Group.Id
}
#endregion

#region create group
Write-Host "Creating or receiving group: $EmergencyAccessGroup" 
$ObjectID_EmergencyAccessGroup = New-AFAzureADGroup -Name $EmergencyAccessGroup

#endregion

#region import policy templates
Write-Host "Importing policy templates"
$Templates = Get-ChildItem -Path $PoliciesFolder
$Policies = foreach($Item in $Templates){
    $Policy = Get-Content -Raw -Path $Item.FullName | ConvertFrom-Json
    $Policy
}
#endregion

#region create or update policies
foreach($Policy in $Policies){
    Write-Host "Working on policy: $($Policy.displayName)" 
    $PolicyNumber = $Policy.displayName.Substring(0, 3)

    #REPLACEMENTS
    Write-Host "Adding emergency access group to policy"

    if($Policy.conditions.users.excludeGroups){
        [System.Collections.ArrayList]$excludeGroups = $Policy.conditions.users.excludeGroups

        #Replace Conditional_Access_Exclusion_EmergencyAccessGroup
        if($excludeGroups.Contains("<EmergencyAccessGroup>")){
            $excludeGroups.Add($ObjectID_EmergencyAccessGroup) > $null
            $excludeGroups.Remove("<EmergencyAccessGroup>") > $null
        }

        $Policy.conditions.users.excludeGroups = $excludeGroups
    }

    #Create or update

    $requestBody = $Policy | ConvertTo-Json -Depth 3

    if($Policy.id){
        Write-Host "Template includes policy id - trying to update existing policy $($Policy.id)" -ForegroundColor Magenta
        $Result = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $Policy.id -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        if($Result){
            Write-Host "Updating existing policy $($Policy.id)" -ForegroundColor Green
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $Policy.id -BodyParameter $requestBody
        }else{
            Write-Host "No existing policy found - abort cannot update" -ForegroundColor Red
        }
    }else{
        Write-Host "Template does not include policy id - creating new policy" -ForegroundColor Green
        New-MgIdentityConditionalAccessPolicy -BodyParameter $requestBody
    }

    Start-Sleep -Seconds 2

}
#endregion

#region disconnect
try{Disconnect-MgGraph -ErrorAction SilentlyContinue}catch{}
#endregion