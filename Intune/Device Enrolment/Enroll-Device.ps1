<#
.SYNOPSIS
This script enrolls devices into Microsoft Intune using a provided provisioning package, and sends enrollment status notifications to a Microsoft Teams channel via a webhook.

.DESCRIPTION
The script performs the following steps:
1. Creates a directory for storing the provisioning package.
2. Downloads the provisioning package from the provided URL.
3. Initiates the Intune enrollment process by applying the provisioning package.
4. Checks the enrollment status in a loop until successful enrollment or a timeout is reached.
5. Sends a notification to a Microsoft Teams channel via a webhook with the enrollment status and relevant log snippets.
6. Optionally cleans up by removing the downloaded provisioning package file.

.PARAMETERS
- $ppkgUrl: URL to download the provisioning package.
- $localPpkgPath: Local path to save the downloaded provisioning package.
- $webhookUrl: URL of the Microsoft Teams webhook for sending notifications.

.USAGE
1. Replace the placeholder values in the Parameters section with your actual values.
2. Save the script to a file, e.g., Enroll-Device.ps1.
3. Run the script in PowerShell: PS> .\Enroll-Device.ps1

.EXAMPLE
PS> .\Enroll-Device.ps1 -ppkgUrl "https://your-ppkg-url" -localPpkgPath "C:\Temp\enrollment.ppkg" -webhookUrl "https://your-teams-webhook-url"

#>

# Function to log messages with timestamp
Function Write-LogMessage {
    Param(
        [string]$Message
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logMessage = "$timestamp - $Message"
    $logMessage | Out-File -FilePath $logFilePath -Append
    Write-Host $logMessage -ForegroundColor Red
}

# Function to send notification to Microsoft Teams via webhook
Function Send-TeamsNotification {
    Param(
        [string]$webhookUrl,
        [string]$message,
        [string]$logSnippet
    )
    $bodyContent = @{
        title = "Intune Device Enrollment Status"
        text = $message
        sections = @(
            @{
                facts = @(
                    @{ name = "Log Snippet"; value = $logSnippet }
                )
            }
        )
    }
    $body = ConvertTo-Json -Depth 4 $bodyContent
    try {
        Invoke-RestMethod -Method Post -Uri $webhookUrl -Body $body -ContentType 'application/json'
    }
    catch {
        Write-LogMessage "Failed to send Teams notification: $($_.Exception)"
    }
}

# Function to extract the last 10 error events related to device enrollment from the event log
Function Get-LogSnippet {
    $logSnippet = Get-WinEvent -LogName 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin' -MaxEvents 10 -ErrorAction SilentlyContinue | Where-Object { $_.LevelDisplayName -eq 'Error' }
    return $logSnippet | Format-List | Out-String
}

# Parameters
$ppkgUrl = "your-ppkg-url"
$localPpkgPath = "C:\Temp\enrollment.ppkg"
$webhookUrl = "your-teams-webhook-url"
$logFilePath = "C:\Yolo\Enroll-Device.log"

# Check if the directory exists, if not, create it
$logDir = [System.IO.Path]::GetDirectoryName($logFilePath)
if (-not (Test-Path $logDir -PathType Container)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

# Check if the log file exists, if not, create it
if (-not (Test-Path $logFilePath)) {
    New-Item -ItemType File -Path $logFilePath -Force
}

if (-not [Uri]::IsWellFormedUriString($ppkgUrl, [UriKind]::Absolute)) {
    Write-LogMessage "The provided PPKG URL is not valid."
    exit 1  # Exit with error code 1
}

if (-not [Uri]::IsWellFormedUriString($webhookUrl, [UriKind]::Absolute)) {
    Write-LogMessage "The provided Teams webhook URL is not valid."
    exit 1  # Exit with error code 1
}

# Create destination directory if it doesn't exist
$destDir = [System.IO.Path]::GetDirectoryName($localPpkgPath)
try {
    if (-not (Test-Path $destDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destDir -Force
        Write-LogMessage "Created destination directory $destDir"
    }
}
catch {
    Write-LogMessage "Failed to create directory ${destDir}: $($_.Exception)"
    exit 1  # Exit with error code 1
}

# Download the provisioning package file
try {
    Invoke-WebRequest -Uri $ppkgUrl -OutFile $localPpkgPath
    Write-LogMessage "Downloaded provisioning package file to $localPpkgPath"
}
catch {
    Write-LogMessage "Failed to download provisioning package file from ${ppkgUrl}: $($_.Exception)"
    exit 1  # Exit with error code 1
}

# Enroll the device into Intune
$process = Start-Process "cmd.exe" "/c ProvisioningUtil.exe /ApplyProvisioningPackage /PackagePath:$localPpkgPath /Quiet" -NoNewWindow -Wait -PassThru
if ($process.ExitCode -eq 0) {
    Write-LogMessage "Initiated device enrollment successfully."
} else {
    $errorMessage = "Failed to initiate device enrollment. Exit code: $($process.ExitCode)"
    Write-LogMessage $errorMessage
    
    # Extract the log snippet from the event log
    $logSnippet = Get-LogSnippet
    
    # Formulate the message to send to Teams
    $message = @"
Enrollment Status: Failed
Device Identifier: $(Get-WmiObject -Class Win32_ComputerSystem).Name
Timestamp: $(Get-Date)
ErrorMessage: $errorMessage
"@
    # Send failure notification to Teams
    Send-TeamsNotification -webhookUrl $webhookUrl -message $message -logSnippet $logSnippet
    
    # Optionally, you could add further error handling here, or exit the script if necessary.
    exit 1  # Exit with error code 1
}

# Dynamic enrollment status checking
$timeout = (Get-Date).AddMinutes(10)  # Set a timeout for 10 minutes
$enrolled = $false
while ((Get-Date) -lt $timeout -and -not $enrolled) {
    # Check enrollment status
    $statusOutput = dsregcmd /status
    if ($statusOutput -match "AzureAdJoined\s+:\s+YES") {
        $enrolled = $true
        # Send success notification
        $message = @"
Enrollment Status: Successful
Device Identifier: $(Get-WmiObject -Class Win32_ComputerSystem).Name
Timestamp: $(Get-Date)
"@
        Send-TeamsNotification -webhookUrl $webhookUrl -message $message -logSnippet ""
    }
    if (-not $enrolled) {
        Start-Sleep -Seconds 30  # Sleep for 30 seconds before checking again
    }
}

if (-not $enrolled) {
    # Extract the log snippet from the event log
    $logSnippet = Get-LogSnippet
    $message = @"
Enrollment Status: Failed
Device Identifier: $(Get-WmiObject -Class Win32_ComputerSystem).Name
Timestamp: $(Get-Date)
"@
    Send-TeamsNotification -webhookUrl $webhookUrl -message $message -logSnippet $logSnippet
}

# Optional: Remove the provisioning package file from the local machine
Remove-Item $localPpkgPath -ErrorAction SilentlyContinue
if (-not (Test-Path $localPpkgPath)) {
    Write-LogMessage "Removed provisioning package file from local machine"
} else {
    Write-LogMessage "Failed to remove provisioning package file from local machine"
}
