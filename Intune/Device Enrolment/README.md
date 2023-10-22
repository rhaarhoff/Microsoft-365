# Intune Device Enrollment Script

This script facilitates the enrollment of devices into Microsoft Intune by utilizing a Provisioning Package (PPKG) created with Windows Configuration Designer (WCD). Additionally, it sends enrollment status notifications to a Microsoft Teams channel via a webhook.

## Pre-requisites

1. **Windows Configuration Designer (WCD)**: Install WCD from the Microsoft Store.
2. **Microsoft Intune**: Ensure you have an Intune subscription and necessary permissions.
3. **Microsoft Teams**: A Microsoft Teams channel to send notifications and a configured webhook.

## Generating the Provisioning Package (PPKG)

Follow the steps below to create a Provisioning Package using Windows Configuration Designer:

1. Launch **Windows Configuration Designer**.
2. Select **Create advanced provisioning package**.
3. Provide a name and optional description for the project.
4. Select **Next** and choose the settings you want to configure.
5. Navigate to **Runtime settings** -> **Workplace** -> **Enroll in MDM** and fill in the necessary fields such as the **MDM Server URL** (usually in the format: `https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc`).
6. Once all settings have been configured, select **Export** -> **Provisioning package**.
7. Provide a name for the package, choose a security level, and select where to save the package.
8. Select **Next** and **Create** to generate the PPKG file.

Upload the generated PPKG file to a shared location or cloud storage, and note down the URL as it will be used in the script.

## Script Parameters

- `$ppkgUrl`: URL to download the provisioning package.
- `$localPpkgPath`: Local path to save the downloaded provisioning package.
- `$webhookUrl`: URL of the Microsoft Teams webhook for sending notifications.

## Usage

1. Replace the placeholder values in the script's Parameters section with your actual values.
2. Save the script to a file, e.g., `Enroll-Device.ps1`, in a directory of your choice. Ensure that the directory has the necessary permissions to read and execute the script.
3. Run the script in PowerShell: `PS> .\Enroll-Device.ps1`

### Example

```powershell
PS> .\Enroll-Device.ps1 -ppkgUrl "https://your-ppkg-url" -localPpkgPath "C:\Temp\enrollment.ppkg" -webhookUrl "https://your-teams-webhook-url"

## Notifications

The script sends a notification to the specified Microsoft Teams channel via a webhook upon the completion or failure of the enrollment process. The notification includes the enrollment status and relevant log snippets.

## Cleanup

Optionally, the script removes the downloaded PPKG file from the local machine after the enrollment process.

## Error Handling and Troubleshooting

- The script logs all activities, and in case of an error, it will provide a descriptive message to help identify the issue.
- Common issues and their resolutions will be documented in a separate `TROUBLESHOOTING.md` file in this repository. Refer to this file for help on resolving common issues.

For more details and support, refer to the official [Microsoft Intune documentation](https://learn.microsoft.com/en-us/mem/intune/fundamentals/what-is-device-management) and [Windows Configuration Designer documentation](https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-install-icd).
