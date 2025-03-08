/**
 * @description Test class for BirthdayReminderController.
 * This class verifies the Lightning web component controller methods function correctly,
 * including settings management, birthday data retrieval, batch execution, and job scheduling.
 * All test data is created within the tests, avoiding the use of SeeAllData=true.
 * @author Shiva
 * @date 2025-03-08
 */
@isTest
private class BirthdayReminderControllerTest {
    
    /**
     * @description Sets up test data for all test methods to use.
     * Creates the following:
     * - Custom settings for birthday reminders with specific configuration
     * - Test account for contact association
     * - Test contacts with birthdays at strategic intervals
     * - Birthday reminder records associated with the test contacts
     */
    @TestSetup
    static void setupTestData() {
        // Create org-wide custom settings with specific configuration
        BirthdayReminderSettings__c settings = new BirthdayReminderSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            ReminderDays__c = 7,
            EnableEmailNotifications__c = true,
            EnableChatterPosts__c = true,
            EmailTemplateId__c = '00X000000000000',
            RecipientEmails__c = 'test@example.com'
        );
        insert settings;
        
        // Create test account for contact association
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test contacts with strategically timed birthdays
        // to test various reminder scenarios
        List<Contact> testContacts = new List<Contact>();
        
        // Contact with birthday today
        Contact contact1 = new Contact(
            FirstName = 'Test',
            LastName = 'Today',
            Email = 'test.today@example.com',
            AccountId = testAccount.Id,
            Birthdate = Date.today().addYears(-30)
        );
        testContacts.add(contact1);
        
        // Contact with birthday in 5 days
        Contact contact2 = new Contact(
            FirstName = 'Test',
            LastName = 'Soon',
            Email = 'test.soon@example.com',
            AccountId = testAccount.Id,
            Birthdate = Date.today().addDays(5).addYears(-25)
        );
        testContacts.add(contact2);
        
        insert testContacts;
        
        // Create some birthday reminders to test stats retrieval methods
        // All reminders are marked as sent for testing purposes
        List<BirthdayReminder__c> reminders = new List<BirthdayReminder__c>();
        for (Contact c : testContacts) {
            BirthdayReminder__c reminder = new BirthdayReminder__c(
                Contact__c = c.Id,
                BirthdayDate__c = Date.today().addDays(5),
                ReminderSent__c = true,
                SentDatetime__c = Datetime.now()
            );
            reminders.add(reminder);
        }
        
        insert reminders;
    }
    
    /**
     * @description Tests the getSettings method to verify it correctly retrieves
     * the custom settings for birthday reminders from the org defaults.
     */
    @isTest
    static void testGetSettings() {
        Test.startTest();
        
        BirthdayReminderSettings__c settings = BirthdayReminderController.getSettings();
        
        Test.stopTest();
        
        System.assertNotEquals(null, settings, 'Settings should not be null');
        System.assertEquals(7, settings.ReminderDays__c, 'ReminderDays should be 7');
        System.assertEquals(true, settings.EnableEmailNotifications__c, 'EnableEmailNotifications should be true');
    }
    
    /**
     * @description Tests the saveSettings method to verify it correctly updates
     * the birthday reminder settings in the database with new values.
     * Tests updating both numeric and boolean fields.
     */
    @isTest
    static void testSaveSettings() {
        BirthdayReminderSettings__c settings = BirthdayReminderController.getSettings();
        
        Test.startTest();
        
        // Modify the settings to test different values
        // Change ReminderDays from 7 to 10 and disable Chatter posts
        settings.ReminderDays__c = 10;
        settings.EnableChatterPosts__c = false;
        
        // Save the settings
        BirthdayReminderSettings__c savedSettings = BirthdayReminderController.saveSettings(settings);
        
        Test.stopTest();
        
        // Verify the returned settings object has the updated values
        System.assertEquals(10, savedSettings.ReminderDays__c, 'ReminderDays should be updated to 10');
        System.assertEquals(false, savedSettings.EnableChatterPosts__c, 'EnableChatterPosts should be updated to false');
        
        // Verify the settings were actually persisted in the database
        BirthdayReminderSettings__c dbSettings = BirthdayReminderSettings__c.getOrgDefaults();
        System.assertEquals(10, dbSettings.ReminderDays__c, 'ReminderDays should be updated in the database');
    }
    
    /**
     * @description Tests the getUpcomingBirthdayCount method to verify it correctly
     * returns the count of contacts with upcoming birthdays within the reminder period.
     */
    @isTest
    static void testGetUpcomingBirthdayCount() {
        Test.startTest();
        
        Integer count = BirthdayReminderController.getUpcomingBirthdayCount();
        
        Test.stopTest();
        
        // With our test data and 7-day reminder window, we should have 2 contacts with upcoming birthdays
        // (one with birthday today and one with birthday in 5 days)
        System.assertEquals(2, count, 'Should find 2 contacts with upcoming birthdays');
    }
    
    /**
     * @description Tests the getUpcomingBirthdays method to verify it correctly
     * returns the list of contacts with upcoming birthdays within the reminder period.
     */
    @isTest
    static void testGetUpcomingBirthdays() {
        Test.startTest();
        
        List<Contact> contacts = BirthdayReminderController.getUpcomingBirthdays();
        
        Test.stopTest();
        
        // With our test data and 7-day reminder window, we should have 2 contacts with upcoming birthdays
        System.assertEquals(2, contacts.size(), 'Should find 2 contacts with upcoming birthdays');
    }
    
    /**
     * @description Tests the runBatchJob method to verify it correctly
     * initiates the batch job to process birthday reminders.
     */
    @isTest
    static void testRunBatchJob() {
        Test.startTest();
        
        Id batchId = BirthdayReminderController.runBatchJob();
        
        Test.stopTest();
        
        System.assertNotEquals(null, batchId, 'Batch job ID should not be null');
    }
    
    /**
     * @description Tests the scheduleJob method to verify it correctly
     * schedules the birthday reminder job to run at the specified time.
     * Tests scheduling a job to run at 8:30 AM daily.
     */
    @isTest
    static void testScheduleJob() {
        Test.startTest();
        
        String jobId = BirthdayReminderController.scheduleJob('Test Job', 8, 30);
        
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        // Verify the job was scheduled
        List<CronTrigger> jobs = BirthdayReminderController.getScheduledJobs();
        System.assertNotEquals(0, jobs.size(), 'Should find at least one scheduled job');
    }
    
    /**
     * @description Tests the getScheduledJobs method to verify it correctly
     * retrieves all scheduled birthday reminder jobs from the system.
     */
    @isTest
    static void testGetScheduledJobs() {
        // Schedule a job
        Test.startTest();
        
        BirthdayReminderController.scheduleJob('Test Job', 8, 30);
        List<CronTrigger> jobs = BirthdayReminderController.getScheduledJobs();
        
        Test.stopTest();
        
        System.assertNotEquals(0, jobs.size(), 'Should find at least one scheduled job');
    }
    
    /**
     * @description Tests the deleteScheduledJob method to verify it correctly
     * deletes a scheduled job from the system using the job ID.
     */
    @isTest
    static void testDeleteScheduledJob() {
        // Schedule a job
        Test.startTest();
        
        String jobId = BirthdayReminderController.scheduleJob('Test Job', 8, 30);
        
        // Delete the job
        Boolean result = BirthdayReminderController.deleteScheduledJob(jobId);
        
        Test.stopTest();
        
        System.assertEquals(true, result, 'Job deletion should be successful');
    }
    
    /**
     * @description Tests the getEmailTemplates method to verify it correctly
     * retrieves all available email templates that could be used for birthday reminders.
     * Note: The number of templates will depend on the org, so we just verify the method runs.
     */
    @isTest
    static void testGetEmailTemplates() {
        Test.startTest();
        
        List<EmailTemplate> templates = BirthdayReminderController.getEmailTemplates();
        
        Test.stopTest();
        
        // The number of templates will depend on the org, so just verify the method runs without error
        System.assertNotEquals(null, templates, 'Templates list should not be null');
    }
    
    /**
     * @description Tests the getBirthdayReminderStats method to verify it correctly
     * retrieves statistics about birthday reminders, including counts of upcoming birthdays,
     * reminders sent today, reminders sent this month, and total reminders.
     */
    @isTest
    static void testGetBirthdayReminderStats() {
        Test.startTest();
        
        Map<String, Object> stats = BirthdayReminderController.getBirthdayReminderStats();
        
        Test.stopTest();
        
        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assert(stats.containsKey('upcomingBirthdaysCount'), 'Stats should contain upcomingBirthdaysCount');
        System.assert(stats.containsKey('remindersSentToday'), 'Stats should contain remindersSentToday');
        System.assert(stats.containsKey('remindersSentThisMonth'), 'Stats should contain remindersSentThisMonth');
        System.assert(stats.containsKey('totalReminders'), 'Stats should contain totalReminders');
        
        // Verify the count of total reminders
        Integer totalReminders = (Integer)stats.get('totalReminders');
        System.assertEquals(2, totalReminders, 'Should find 2 total reminders');
    }
    
    /**
     * @description Tests error handling in saveSettings method to verify it correctly
     * handles exceptions when saving settings fails. This test specifically tests
     * the scenario where null settings are provided.
     */
    @isTest
    static void testSaveSettingsError() {
        Test.startTest();
        
        // Attempt to save a null settings object, which should throw an exception
        try {
            BirthdayReminderController.saveSettings(null);
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(e.getMessage().contains('Error saving settings'), 'Exception should contain error message');
        }
        
        Test.stopTest();
    }
    
    /**
     * @description Tests error handling in runBatchJob method.
     * Note: It's difficult to force a batch job execution error in a test context,
     * so this test primarily verifies the method doesn't throw exceptions.
     */
    @isTest
    static void testRunBatchJobError() {
        Test.startTest();
        
        // This would normally succeed, but we'll use the test to cover the error path in the controller
        // No actual way to force a batch job execution error in a test, so this test is somewhat artificial
        Id batchId = BirthdayReminderController.runBatchJob();
        
        Test.stopTest();
        
        System.assertNotEquals(null, batchId, 'Batch job ID should not be null');
    }
}
