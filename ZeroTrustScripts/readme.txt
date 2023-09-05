Extract the zip file to a directory on your local machine, e.g. C:\temp\

The CAPolicies folder contains an import script and three subfolders containing JSON files (individual CA policies);
Run the script with proper parameters, e.g.:
.\Import-CAPolicies.ps1 -PoliciesFolder C:\temp\CAPolicies\Baseline -EmergencyAccessGroup sg-Breakglass
(Note: This script requires the Microsoft Graph PowerShell SDK for Azure AD)

The IntunePolicies folder contains a script to import the MAM and MDM policies. 
Also included subfolders with JSON files for reference.
.\Import-MamAndMdmPolicies.ps1 