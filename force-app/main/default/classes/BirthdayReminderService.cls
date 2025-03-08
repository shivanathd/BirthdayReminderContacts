/**
 * @description Service class for Birthday Reminder functionality
 * @author Shiva
 * @date 2025-03-08
 */
public with sharing class BirthdayReminderService {
    
    /**
     * @description Finds contacts with upcoming birthdays based on the configured reminder days
     * @return List<Contact> List of contacts with upcoming birthdays
     */
    public List<Contact> findContactsWithUpcomingBirthdays() {
        BirthdayReminderSettings__c settings = getSettings();
        Integer reminderDays = (Integer)settings.ReminderDays__c;
        
        // Calculate the date range for birthday detection
        Date today = Date.today();
        Date endDate = today.addDays(reminderDays);
        
        // Handle cross-year boundary cases
        List<Contact> contactsWithUpcomingBirthdays = new List<Contact>();
        
        // Current year birthdays within the window
        Date currentYearStartDate = Date.newInstance(today.year(), today.month(), today.day());
        Date currentYearEndDate = Date.newInstance(endDate.year(), endDate.month(), endDate.day());
        
        String currentYearQuery = 'SELECT Id, Name, Birthdate, Email, Phone FROM Contact ' +
                                'WHERE Birthdate != null ' +
                                'AND DAY_IN_YEAR(Birthdate) >= DAY_IN_YEAR(:currentYearStartDate) ' +
                                'AND DAY_IN_YEAR(Birthdate) <= DAY_IN_YEAR(:currentYearEndDate)';
        
        contactsWithUpcomingBirthdays.addAll(Database.query(currentYearQuery));
        
        // Handle December to January crossover if needed
        if (today.month() == 12 || (today.month() + (reminderDays / 30) > 12)) {
            Date nextYearStartDate = Date.newInstance(today.year(), 1, 1);
            Date nextYearEndDate = Date.newInstance(today.year(), 1, 31);
            
            if (endDate.month() == 1 || endDate.daysBetween(nextYearEndDate) < 0) {
                String nextYearQuery = 'SELECT Id, Name, Birthdate, Email, Phone FROM Contact ' +
                                    'WHERE Birthdate != null ' +
                                    'AND DAY_IN_YEAR(Birthdate) >= 1 ' +
                                    'AND DAY_IN_YEAR(Birthdate) <= DAY_IN_YEAR(:nextYearEndDate)';
                
                contactsWithUpcomingBirthdays.addAll(Database.query(nextYearQuery));
            }
        }
        
        // Filter out contacts for whom we've already created reminders this year
        filterContactsWithExistingReminders(contactsWithUpcomingBirthdays);
        
        return contactsWithUpcomingBirthdays;
    }
    
    /**
     * @description Filter out contacts who already have reminders created for this year
     * @param contacts List of contacts to filter
     */
    private void filterContactsWithExistingReminders(List<Contact> contacts) {
        if (contacts.isEmpty()) {
            return;
        }
        
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        // Get the current year
        Integer currentYear = Date.today().year();
        
        // Find existing reminders for these contacts within the current year
        List<BirthdayReminder__c> existingReminders = [
            SELECT Contact__c
            FROM BirthdayReminder__c
            WHERE Contact__c IN :contactIds
            AND CALENDAR_YEAR(CreatedDate) = :currentYear
        ];
        
        Set<Id> contactsWithExistingReminders = new Set<Id>();
        for (BirthdayReminder__c reminder : existingReminders) {
            contactsWithExistingReminders.add(reminder.Contact__c);
        }
        
        // Remove contacts that already have reminders
        List<Contact> filteredContacts = new List<Contact>();
        for (Contact c : contacts) {
            if (!contactsWithExistingReminders.contains(c.Id)) {
                filteredContacts.add(c);
            }
        }
        
        contacts.clear();
        contacts.addAll(filteredContacts);
    }
    
    /**
     * @description Creates reminder records for the specified contacts
     * @param contacts List of contacts to create reminders for
     * @return List<BirthdayReminder__c> List of created reminder records
     */
    public List<BirthdayReminder__c> createBirthdayReminders(List<Contact> contacts) {
        List<BirthdayReminder__c> reminders = new List<BirthdayReminder__c>();
        
        for (Contact contact : contacts) {
            BirthdayReminder__c reminder = new BirthdayReminder__c(
                Contact__c = contact.Id,
                BirthdayDate__c = getBirthdayDateThisYear(contact.Birthdate),
                ReminderSent__c = false
            );
            
            reminders.add(reminder);
        }
        
        if (!reminders.isEmpty()) {
            insert reminders;
        }
        
        return reminders;
    }
    
    /**
     * @description Calculates the birthday date for the current year
     * @param birthdate The contact's original birthdate
     * @return Date The birthday date for the current year
     */
    private Date getBirthdayDateThisYear(Date birthdate) {
        Integer currentYear = Date.today().year();
        Date birthdayThisYear = Date.newInstance(currentYear, birthdate.month(), birthdate.day());
        
        // If the birthday has already passed this year, use next year
        if (birthdayThisYear < Date.today()) {
            birthdayThisYear = Date.newInstance(currentYear + 1, birthdate.month(), birthdate.day());
        }
        
        return birthdayThisYear;
    }
    
    /**
     * @description Sends notifications for the specified reminders
     * @param reminders List of reminder records to send notifications for
     */
    public void sendNotifications(List<BirthdayReminder__c> reminders) {
        if (reminders.isEmpty()) {
            return;
        }
        
        BirthdayReminderSettings__c settings = getSettings();
        
        // Get the contacts for these reminders
        Set<Id> contactIds = new Set<Id>();
        for (BirthdayReminder__c reminder : reminders) {
            contactIds.add(reminder.Contact__c);
        }
        
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([
            SELECT Id, Name, Birthdate, Email, Phone
            FROM Contact
            WHERE Id IN :contactIds
        ]);
        
        List<BirthdayReminder__c> sentReminders = new List<BirthdayReminder__c>();
        
        // Send email notifications if enabled
        if (settings.EnableEmailNotifications__c) {
            sendEmailNotifications(reminders, contactsMap, settings);
        }
        
        // Send Chatter posts if enabled
        if (settings.EnableChatterPosts__c) {
            postToChatter(reminders, contactsMap);
        }
        
        // Update reminder records to indicate notifications were sent
        for (BirthdayReminder__c reminder : reminders) {
            reminder.ReminderSent__c = true;
            reminder.SentDatetime__c = Datetime.now();
            sentReminders.add(reminder);
        }
        
        if (!sentReminders.isEmpty()) {
            update sentReminders;
        }
    }
    
    /**
     * @description Sends email notifications for the specified reminders
     * @param reminders List of reminder records
     * @param contactsMap Map of Contact records by Id
     * @param settings Custom settings for the Birthday Reminder app
     */
    private void sendEmailNotifications(List<BirthdayReminder__c> reminders, Map<Id, Contact> contactsMap, BirthdayReminderSettings__c settings) {
        String emailTemplateId = settings.EmailTemplateId__c;
        
        if (String.isBlank(emailTemplateId)) {
            System.debug(LoggingLevel.ERROR, 'Email Template ID is not configured in Birthday Reminder Settings');
            return;
        }
        
        String recipientEmails = settings.RecipientEmails__c;
        if (String.isBlank(recipientEmails)) {
            System.debug(LoggingLevel.ERROR, 'Recipient Emails are not configured in Birthday Reminder Settings');
            return;
        }
        
        List<String> toAddresses = recipientEmails.split(',');
        List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();
        
        for (BirthdayReminder__c reminder : reminders) {
            Contact contact = contactsMap.get(reminder.Contact__c);
            if (contact != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(emailTemplateId);
                email.setTargetObjectId(reminder.Contact__c);
                email.setSaveAsActivity(false);
                email.setToAddresses(toAddresses);
                email.setWhatId(reminder.Id);
                
                emailMessages.add(email);
            }
        }
        
        if (!emailMessages.isEmpty()) {
            try {
                Messaging.sendEmail(emailMessages);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error sending email notifications: ' + e.getMessage());
            }
        }
    }
    
    /**
     * @description Posts birthday reminders to Chatter
     * @param reminders List of reminder records
     * @param contactsMap Map of Contact records by Id
     */
    private void postToChatter(List<BirthdayReminder__c> reminders, Map<Id, Contact> contactsMap) {
        List<FeedItem> feedItems = new List<FeedItem>();
        
        for (BirthdayReminder__c reminder : reminders) {
            Contact contact = contactsMap.get(reminder.Contact__c);
            if (contact != null) {
                Integer age = calculateAge(contact.Birthdate);
                String message = contact.Name + ' has a birthday on ' + 
                                reminder.BirthdayDate__c.format() + 
                                (age > 0 ? ' turning ' + age : '') + 
                                '. Please wish them a happy birthday!';
                
                FeedItem post = new FeedItem();
                post.ParentId = UserInfo.getUserId(); // Post to the current user's feed
                post.Body = message;
                post.Type = 'TextPost';
                
                feedItems.add(post);
            }
        }
        
        if (!feedItems.isEmpty()) {
            try {
                insert feedItems;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error posting to Chatter: ' + e.getMessage());
            }
        }
    }
    
    /**
     * @description Calculates the age based on a birthdate
     * @param birthdate The birthdate to calculate age from
     * @return Integer The calculated age
     */
    private Integer calculateAge(Date birthdate) {
        if (birthdate == null) {
            return 0;
        }
        
        Date today = Date.today();
        Integer age = today.year() - birthdate.year();
        
        // Adjust age if birthday hasn't occurred yet this year
        if (today.month() < birthdate.month() || 
            (today.month() == birthdate.month() && today.day() < birthdate.day())) {
            age--;
        }
        
        return age;
    }
    
    /**
     * @description Gets the Birthday Reminder Settings
     * @return BirthdayReminderSettings__c The settings record
     */
    public BirthdayReminderSettings__c getSettings() {
        BirthdayReminderSettings__c settings = BirthdayReminderSettings__c.getOrgDefaults();
        
        if (settings.Id == null) {
            // Create default settings if none exist
            settings = new BirthdayReminderSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                ReminderDays__c = 7,
                EnableEmailNotifications__c = true,
                EnableChatterPosts__c = false
            );
            
            try {
                insert settings;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error creating default Birthday Reminder Settings: ' + e.getMessage());
            }
        }
        
        return settings;
    }
}
