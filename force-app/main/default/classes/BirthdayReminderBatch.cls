/**
 * @description Batch class for processing Birthday Reminders
 * @author Shiva
 * @date 2025-03-08
 */
global class BirthdayReminderBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private BirthdayReminderService reminderService;
    private List<BirthdayReminder__c> createdReminders;
    private Integer processedContacts = 0;
    private Integer sentNotifications = 0;
    
    /**
     * @description Constructor
     */
    global BirthdayReminderBatch() {
        this.reminderService = new BirthdayReminderService();
        this.createdReminders = new List<BirthdayReminder__c>();
    }
    
    /**
     * @description Start method for the batch process
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Find contacts with birthdays in the configured window
        List<Contact> contactsWithUpcomingBirthdays = reminderService.findContactsWithUpcomingBirthdays();
        
        // If we found contacts, create reminders
        if (!contactsWithUpcomingBirthdays.isEmpty()) {
            try {
                createdReminders = reminderService.createBirthdayReminders(contactsWithUpcomingBirthdays);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error creating birthday reminders: ' + e.getMessage());
            }
        }
        
        // Query created reminders for processing
        return Database.getQueryLocator([
            SELECT Id, Contact__c, BirthdayDate__c, ReminderSent__c, SentDatetime__c
            FROM BirthdayReminder__c
            WHERE ReminderSent__c = false
        ]);
    }
    
    /**
     * @description Execute method for the batch process
     * @param bc BatchableContext
     * @param scope List of records to process
     */
    global void execute(Database.BatchableContext bc, List<BirthdayReminder__c> scope) {
        if (scope.isEmpty()) {
            return;
        }
        
        processedContacts += scope.size();
        
        try {
            reminderService.sendNotifications(scope);
            sentNotifications += scope.size();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending birthday notifications: ' + e.getMessage());
        }
    }
    
    /**
     * @description Finish method for the batch process
     * @param bc BatchableContext
     */
    global void finish(Database.BatchableContext bc) {
        // Log completion details
        System.debug(LoggingLevel.INFO, 'Birthday Reminder Batch completed.');
        System.debug(LoggingLevel.INFO, 'Created reminders: ' + createdReminders.size());
        System.debug(LoggingLevel.INFO, 'Processed contacts: ' + processedContacts);
        System.debug(LoggingLevel.INFO, 'Sent notifications: ' + sentNotifications);
        
        // Optionally send admin email notification about batch completion
        BirthdayReminderSettings__c settings = reminderService.getSettings();
        if (settings.EnableEmailNotifications__c && !String.isBlank(settings.RecipientEmails__c)) {
            sendBatchCompletionEmail(settings);
        }
    }
    
    /**
     * @description Sends an email notification about batch completion
     * @param settings Birthday Reminder Settings
     */
    private void sendBatchCompletionEmail(BirthdayReminderSettings__c settings) {
        String recipientEmails = settings.RecipientEmails__c;
        if (String.isBlank(recipientEmails)) {
            return;
        }
        
        List<String> toAddresses = recipientEmails.split(',');
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);
        email.setSubject('Birthday Reminder Batch Job Completed');
        
        String emailBody = 'The Birthday Reminder batch job has completed.\n\n' +
                          'Created reminders: ' + createdReminders.size() + '\n' +
                          'Processed contacts: ' + processedContacts + '\n' +
                          'Sent notifications: ' + sentNotifications + '\n\n' +
                          'Date/Time: ' + Datetime.now();
        
        email.setPlainTextBody(emailBody);
        
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending batch completion email: ' + e.getMessage());
        }
    }
}
