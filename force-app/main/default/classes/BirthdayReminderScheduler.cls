/**
 * @description Scheduler class for the Birthday Reminder batch job
 * @author Shiva
 * @date 2025-03-08
 */
global class BirthdayReminderScheduler implements Schedulable {
    
    /**
     * @description Execute method for the scheduler
     * @param sc SchedulableContext
     */
    global void execute(SchedulableContext sc) {
        // Create and execute the batch job
        BirthdayReminderBatch batchJob = new BirthdayReminderBatch();
        
        // Get batch size from settings, defaulting to 200 if not configured
        Integer batchSize = 200;
        
        // Execute the batch job
        Database.executeBatch(batchJob, batchSize);
        
        System.debug(LoggingLevel.INFO, 'Birthday Reminder batch job scheduled and started.');
    }
    
    /**
     * @description Schedules the birthday reminder job to run daily at the specified time
     * @param jobName The name for the scheduled job
     * @param hour The hour to run the job (0-23)
     * @param minute The minute to run the job (0-59)
     * @return String The scheduled job ID
     */
    public static String scheduleDaily(String jobName, Integer hour, Integer minute) {
        if (String.isBlank(jobName)) {
            jobName = 'Birthday Reminder Job';
        }
        
        // Validate hour and minute
        hour = (hour < 0 || hour > 23) ? 0 : hour;
        minute = (minute < 0 || minute > 59) ? 0 : minute;
        
        // Create the CRON expression for daily execution at the specified time
        String cronExp = '0 ' + minute + ' ' + hour + ' * * ?';
        
        // Schedule the job
        BirthdayReminderScheduler scheduler = new BirthdayReminderScheduler();
        return System.schedule(jobName, cronExp, scheduler);
    }
}
