/**
 * @description Controller class for Birthday Reminder configuration components
 * @author Shiva
 * @date 2025-03-08
 */
public with sharing class BirthdayReminderController {
    
    /**
     * @description Gets the current Birthday Reminder Settings
     * @return BirthdayReminderSettings__c The settings record
     */
    @AuraEnabled(cacheable=true)
    public static BirthdayReminderSettings__c getSettings() {
        BirthdayReminderService service = new BirthdayReminderService();
        return service.getSettings();
    }
    
    /**
     * @description Saves the Birthday Reminder Settings
     * @param settings The settings record to save
     * @return BirthdayReminderSettings__c The saved settings record
     */
    @AuraEnabled
    public static BirthdayReminderSettings__c saveSettings(BirthdayReminderSettings__c settings) {
        try {
            if (settings.Id != null) {
                update settings;
            } else {
                settings.SetupOwnerId = UserInfo.getOrganizationId();
                insert settings;
            }
            
            return settings;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving settings: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets the count of upcoming birthday reminders
     * @return Integer The count of upcoming birthday reminders
     */
    @AuraEnabled(cacheable=true)
    public static Integer getUpcomingBirthdayCount() {
        BirthdayReminderService service = new BirthdayReminderService();
        List<Contact> contacts = service.findContactsWithUpcomingBirthdays();
        return contacts.size();
    }
    
    /**
     * @description Gets the list of upcoming birthday reminders
     * @return List<Contact> The list of contacts with upcoming birthdays
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getUpcomingBirthdays() {
        BirthdayReminderService service = new BirthdayReminderService();
        return service.findContactsWithUpcomingBirthdays();
    }
    
    /**
     * @description Runs the Birthday Reminder batch job immediately
     * @return Id The batch job ID
     */
    @AuraEnabled
    public static Id runBatchJob() {
        try {
            BirthdayReminderBatch batchJob = new BirthdayReminderBatch();
            return Database.executeBatch(batchJob, 200);
        } catch (Exception e) {
            throw new AuraHandledException('Error running batch job: ' + e.getMessage());
        }
    }
    
    /**
     * @description Schedules the Birthday Reminder job to run daily
     * @param jobName The name for the scheduled job
     * @param hour The hour to run the job (0-23)
     * @param minute The minute to run the job (0-59)
     * @return String The scheduled job ID
     */
    @AuraEnabled
    public static String scheduleJob(String jobName, Integer hour, Integer minute) {
        try {
            return BirthdayReminderScheduler.scheduleDaily(jobName, hour, minute);
        } catch (Exception e) {
            throw new AuraHandledException('Error scheduling job: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets a list of active scheduled Birthday Reminder jobs
     * @return List<CronTrigger> The list of scheduled jobs
     */
    @AuraEnabled(cacheable=true)
    public static List<CronTrigger> getScheduledJobs() {
        return [
            SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression, 
                   TimesTriggered, NextFireTime, State
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Birthday Reminder%'
            ORDER BY NextFireTime ASC
        ];
    }
    
    /**
     * @description Deletes a scheduled job
     * @param jobId The ID of the job to delete
     * @return Boolean True if successful, false otherwise
     */
    @AuraEnabled
    public static Boolean deleteScheduledJob(String jobId) {
        try {
            System.abortJob(jobId);
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting scheduled job: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets a list of available email templates
     * @return List<EmailTemplate> The list of email templates
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailTemplates() {
        return [
            SELECT Id, Name, FolderId, Folder.Name, Description, Subject, 
                   IsActive, DevName, DeveloperName
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Folder.Name, Name
        ];
    }
    
    /**
     * @description Gets the statistics of Birthday Reminders
     * @return Map<String, Object> The statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBirthdayReminderStats() {
        Map<String, Object> stats = new Map<String, Object>();
        
        // Get count of upcoming birthdays
        BirthdayReminderService service = new BirthdayReminderService();
        List<Contact> upcomingBirthdays = service.findContactsWithUpcomingBirthdays();
        stats.put('upcomingBirthdaysCount', upcomingBirthdays.size());
        
        // Get count of sent reminders today
        Integer remindersSentToday = [
            SELECT COUNT()
            FROM BirthdayReminder__c
            WHERE ReminderSent__c = true
            AND SentDatetime__c >= TODAY
        ];
        stats.put('remindersSentToday', remindersSentToday);
        
        // Get count of total reminders sent this month
        Date today = Date.today();
        Date firstDayOfMonth = Date.newInstance(today.year(), today.month(), 1);
        Date firstDayOfNextMonth = firstDayOfMonth.addMonths(1);
        
        Integer remindersSentThisMonth = [
            SELECT COUNT()
            FROM BirthdayReminder__c
            WHERE ReminderSent__c = true
            AND SentDatetime__c >= :firstDayOfMonth
            AND SentDatetime__c < :firstDayOfNextMonth
        ];
        stats.put('remindersSentThisMonth', remindersSentThisMonth);
        
        // Get count of total reminders in the system
        Integer totalReminders = [
            SELECT COUNT()
            FROM BirthdayReminder__c
        ];
        stats.put('totalReminders', totalReminders);
        
        return stats;
    }
}
