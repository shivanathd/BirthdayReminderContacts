/**
 * @description Test class for BirthdayReminderBatch and BirthdayReminderScheduler.
 * This class verifies the batch job correctly processes contacts with upcoming birthdays
 * and that the scheduler correctly schedules and executes the batch job.
 * All test data is created within the tests, avoiding the use of SeeAllData=true.
 * @author Shiva
 * @date 2025-03-08
 */
@isTest
private class BirthdayReminderBatchTest {
    
    /**
     * @description Sets up test data for all test methods to use.
     * Creates the following:
     * - Custom settings for birthday reminders with specific configuration
     * - Test account for contact association
     * - Test contacts with birthdays at different intervals to test various reminder scenarios
     */
    @TestSetup
    static void setupTestData() {
        // Create test settings with specific configuration
        // EnableChatterPosts is set to false to verify email-only notifications
        BirthdayReminderSettings__c settings = new BirthdayReminderSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            ReminderDays__c = 7,
            EnableEmailNotifications__c = true,
            EnableChatterPosts__c = false,
            EmailTemplateId__c = '00X000000000000',
            RecipientEmails__c = 'test@example.com'
        );
        insert settings;
        
        // Create test account for contact association
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test contacts with strategically timed birthdays
        // to verify batch processing logic
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
        
        // Contact with birthday in 3 days
        Contact contact2 = new Contact(
            FirstName = 'Test',
            LastName = 'Soon',
            Email = 'test.soon@example.com',
            AccountId = testAccount.Id,
            Birthdate = Date.today().addDays(3).addYears(-25)
        );
        testContacts.add(contact2);
        
        insert testContacts;
    }
    
    /**
     * @description Tests the batch job execution to verify it correctly:
     * 1. Identifies contacts with upcoming birthdays
     * 2. Creates birthday reminder records
     * 3. Sends notifications
     * 4. Updates reminder records to mark them as sent
     */
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        
        // Execute the batch job with scope size of 200 records
        BirthdayReminderBatch batchJob = new BirthdayReminderBatch();
        Database.executeBatch(batchJob, 200);
        
        Test.stopTest();
        
        // After Test.stopTest(), the batch job will have been fully processed synchronously
        // Verify reminders were created and updated
        List<BirthdayReminder__c> reminders = [
            SELECT Id, Contact__c, BirthdayDate__c, ReminderSent__c, SentDatetime__c
            FROM BirthdayReminder__c
        ];
        
        // We expect 2 reminders from the test contacts (birthdays today and in 3 days)
        System.assertEquals(2, reminders.size(), 'Expected 2 reminders to be created');
        
        // All reminders should be marked as sent
        for (BirthdayReminder__c reminder : reminders) {
            System.assertEquals(true, reminder.ReminderSent__c, 'Reminder should be marked as sent');
            System.assertNotEquals(null, reminder.SentDatetime__c, 'Sent datetime should be populated');
        }
    }
    
    /**
     * @description Tests the scheduler to verify it correctly:
     * 1. Schedules a job with the specified time (8:00 AM daily)
     * 2. Creates a valid CronTrigger with the correct CRON expression
     * 3. Successfully executes the scheduled job
     */
    @isTest
    static void testScheduler() {
        Test.startTest();
        
        // Schedule the job to run at 8:00 AM daily
        String jobId = BirthdayReminderScheduler.scheduleDaily('Test Birthday Reminder Job', 8, 0);
        
        // Verify the job was scheduled by checking that a non-null ID was returned
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        // Query the scheduled job
        CronTrigger cronTrigger = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        // Verify the cron expression
        System.assertEquals('0 0 8 * * ?', cronTrigger.CronExpression, 'Cron expression should be 0 0 8 * * ?');
        
        // Execute the scheduled job manually to verify it works correctly
        BirthdayReminderScheduler scheduler = new BirthdayReminderScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // After Test.stopTest(), the batch job will have been fully processed synchronously
        // Verify reminders were created and updated
        List<BirthdayReminder__c> reminders = [
            SELECT Id, Contact__c, BirthdayDate__c, ReminderSent__c, SentDatetime__c
            FROM BirthdayReminder__c
        ];
        
        // We expect 2 reminders from the test contacts
        System.assertNotEquals(0, reminders.size(), 'Expected reminders to be created');
    }
    
    /**
     * @description Tests the scheduler with invalid parameters to verify it correctly
     * handles boundary conditions and parameter validation. 
     * Tests that invalid hour (-1) and minute (60) values default to 0:00.
     */
    @isTest
    static void testSchedulerWithInvalidParams() {
        Test.startTest();
        
        // Schedule with invalid hour (-1) and minute (60) values
        // Should default to midnight (0:00)
        String jobId = BirthdayReminderScheduler.scheduleDaily('Test Birthday Reminder Job', -1, 60);
        
        // Verify the job was scheduled with default values (0:00)
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        // Query the scheduled job
        CronTrigger cronTrigger = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        // Verify the cron expression (should default to 0:00)
        System.assertEquals('0 0 0 * * ?', cronTrigger.CronExpression, 'Cron expression should be 0 0 0 * * ?');
        
        Test.stopTest();
    }
    
    /**
     * @description Tests the scenario when no contacts have upcoming birthdays
     * to verify the batch job gracefully handles empty data sets without errors.
     */
    @isTest
    static void testNoUpcomingBirthdays() {
        // Delete all contacts
        delete [SELECT Id FROM Contact];
        
        Test.startTest();
        
        // Execute the batch job
        BirthdayReminderBatch batchJob = new BirthdayReminderBatch();
        Database.executeBatch(batchJob, 200);
        
        Test.stopTest();
        
        // Verify no reminders were created
        List<BirthdayReminder__c> reminders = [
            SELECT Id
            FROM BirthdayReminder__c
        ];
        
        System.assertEquals(0, reminders.size(), 'Expected no reminders to be created');
    }
    
    /**
     * @description Tests batch job with existing reminders that have not been sent.
     * Verifies the batch job correctly processes pre-existing reminder records
     * and updates them to mark them as sent.
     */
    @isTest
    static void testBatchWithExistingReminders() {
        // Create reminders directly in the database without using the service class
        // to simulate pre-existing records that need to be processed
        List<Contact> contacts = [SELECT Id, Birthdate FROM Contact];
        List<BirthdayReminder__c> reminders = new List<BirthdayReminder__c>();
        
        for (Contact contact : contacts) {
            BirthdayReminder__c reminder = new BirthdayReminder__c(
                Contact__c = contact.Id,
                BirthdayDate__c = Date.today().addDays(3),
                ReminderSent__c = false
            );
            reminders.add(reminder);
        }
        
        insert reminders;
        
        Test.startTest();
        
        // Execute the batch job
        BirthdayReminderBatch batchJob = new BirthdayReminderBatch();
        Database.executeBatch(batchJob, 200);
        
        Test.stopTest();
        
        // Verify all reminders were updated with correct sent status and timestamp
        List<BirthdayReminder__c> updatedReminders = [
            SELECT Id, ReminderSent__c, SentDatetime__c
            FROM BirthdayReminder__c
        ];
        
        for (BirthdayReminder__c reminder : updatedReminders) {
            System.assertEquals(true, reminder.ReminderSent__c, 'Reminder should be marked as sent');
            System.assertNotEquals(null, reminder.SentDatetime__c, 'Sent datetime should be populated');
        }
    }
}
