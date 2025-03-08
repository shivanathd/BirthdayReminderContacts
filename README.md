# Salesforce Birthday Reminder App

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com)

## Purpose

This application automatically identifies contacts with upcoming birthdays and sends notifications through email and/or Chatter. The system is highly configurable and allows admins to control notification timing, recipients, and delivery methods. It helps organizations maintain strong relationships with contacts by acknowledging important personal dates without manual tracking.

## Features

- Daily scan of Contact records for upcoming birthdays
- Configurable reminder window (default 7 days)
- Multiple notification channels:
  - Email notifications
  - Chatter posts (optional)
- Tracking of sent reminders
- Admin dashboard for monitoring and configuration
- Batch processing for scalability
- Automated scheduling
- Comprehensive test coverage

## Components

### Custom Objects
- **BirthdayReminderSettings__c**: Custom Settings for app configuration
- **BirthdayReminder__c**: Custom Object to track birthday reminders

### Apex Classes
- **BirthdayReminderService**: Core service class with business logic
- **BirthdayReminderBatch**: Batch Apex for processing contacts efficiently
- **BirthdayReminderScheduler**: Scheduler class to run the job automatically
- **BirthdayReminderController**: Controller for admin configuration components
- Test classes for code coverage and quality assurance

### Lightning Web Components
- **birthdayReminderAdmin**: LWC for configuring and monitoring the app

### Email Template
- **BirthdayReminderTemplate**: Sample email template for birthday notifications

## Deployment

### Prerequisites
- Salesforce org with API access
- Salesforce CLI or Visual Studio Code with Salesforce Extensions

### Deployment Steps

#### Option 1: Deploy using Salesforce CLI

1. Clone this repository or download the files
2. Open a terminal or command prompt
3. Navigate to the project directory (where sfdx-project.json is located)
4. Authenticate to your Salesforce org:
   ```
   sfdx auth:web:login -d -a YourOrgAlias
   ```
5. Deploy the components:
   ```
   sfdx force:source:deploy -p force-app/main/default -u YourOrgAlias
   ```

#### Option 2: Deploy using Visual Studio Code

1. Clone this repository or download the files
2. Open the project folder in VS Code
3. Connect to your Salesforce org using the Org Picker in the VS Code footer
4. Right-click on the `force-app/main/default` folder in the Explorer
5. Select "SFDX: Deploy Source to Org"

## Post-Deployment Configuration

After successful deployment, follow these steps to configure the app:

1. Open your Salesforce org
2. Navigate to the "Birthday Reminder" tab
3. Configure the settings:
   - **Reminder Days**: Set the number of days in advance to send reminders (default: 7)
   - **Email Template ID**: Select or enter the ID of the email template to use
   - **Recipient Emails**: Enter comma-separated email addresses that should receive notifications
   - **Enable Email Notifications**: Toggle to enable/disable email notifications
   - **Enable Chatter Posts**: Toggle to enable/disable Chatter posts
4. Click "Save Settings"
5. On the "Schedule" tab, configure the job schedule:
   - **Job Name**: Enter a name for the scheduled job
   - **Hour**: Select the hour of the day to run the job
   - **Minute**: Select the minute of the hour to run the job
6. Click "Schedule Job"

## Testing the App

To test the app immediately after configuration:

1. Navigate to the "Birthday Reminder" tab
2. Click the "Run Now" button
3. Check the "Dashboard" tab to see statistics on reminders
4. Verify that notifications were sent as configured

## Security Considerations

- The app uses "with sharing" on its Apex classes to respect Salesforce's sharing model
- Ensure that users who need to manage the app have access to the custom objects and permissions

## Troubleshooting

If no notifications are being sent:
1. Verify that contacts have birthdays within the configured reminder window
2. Check that the email template ID is valid
3. Ensure recipient email addresses are correctly entered
4. Check system debug logs for any errors during batch execution

## What's Not Supported Yet

- **SMS Notifications**: Currently, the app only supports email and Chatter notifications. SMS functionality may be added in future releases.
- **Custom Birthday Fields**: The app currently works with the standard Contact birthdate field. Support for custom birthday fields is planned.
- **Multiple Languages**: Email templates are currently not internationalized.
- **External Contact Sources**: The system only works with Contacts stored in Salesforce, not external data sources.
- **Mobile App Interface**: Currently only available through the standard Salesforce interface.

## Other Aspects

### Performance Considerations
- The batch process is designed to handle large volumes of Contact records efficiently
- For orgs with over 1 million contacts, consider adjusting batch size in the BirthdayReminderBatch class

### Extensibility
- The modular design allows for adding new notification channels
- Custom handlers can be created by extending the core service class

### Upcoming Features
- Mobile notifications integration
- Analytics dashboard for birthday campaigns
- Integration with marketing automation for birthday campaigns

## License

This project is licensed under the MIT License.

---

For questions or support, please contact the package author.
