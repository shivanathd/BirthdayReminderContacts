import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Import Apex methods
import getSettings from '@salesforce/apex/BirthdayReminderController.getSettings';
import saveSettings from '@salesforce/apex/BirthdayReminderController.saveSettings';
import getUpcomingBirthdayCount from '@salesforce/apex/BirthdayReminderController.getUpcomingBirthdayCount';
import runBatchJob from '@salesforce/apex/BirthdayReminderController.runBatchJob';
import scheduleJob from '@salesforce/apex/BirthdayReminderController.scheduleJob';
import getScheduledJobs from '@salesforce/apex/BirthdayReminderController.getScheduledJobs';
import deleteScheduledJob from '@salesforce/apex/BirthdayReminderController.deleteScheduledJob';
import getBirthdayReminderStats from '@salesforce/apex/BirthdayReminderController.getBirthdayReminderStats';
import getEmailTemplates from '@salesforce/apex/BirthdayReminderController.getEmailTemplates';

export default class BirthdayReminderAdmin extends LightningElement {
    @track settings;
    @track stats;
    @track scheduledJobs;
    @track emailTemplates;
    @track isLoading = true;
    @track jobName = 'Birthday Reminder Job';
    @track scheduledHour = 8;
    @track scheduledMinute = 0;
    @track error;
    @track activeTab = 'settings';
    
    wiredSettingsResult;
    wiredStatsResult;
    wiredJobsResult;
    wiredTemplatesResult;
    
    // Get settings
    @wire(getSettings)
    wiredSettings(result) {
        this.wiredSettingsResult = result;
        if (result.data) {
            this.settings = { ...result.data };
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.settings = undefined;
            this.showToast('Error', 'Error loading settings: ' + this.error.message, 'error');
        }
        this.isLoading = false;
    }
    
    // Get statistics
    @wire(getBirthdayReminderStats)
    wiredStats(result) {
        this.wiredStatsResult = result;
        if (result.data) {
            this.stats = { ...result.data };
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.stats = undefined;
            this.showToast('Error', 'Error loading stats: ' + this.error.message, 'error');
        }
    }
    
    // Get scheduled jobs
    @wire(getScheduledJobs)
    wiredJobs(result) {
        this.wiredJobsResult = result;
        if (result.data) {
            this.scheduledJobs = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.scheduledJobs = undefined;
            this.showToast('Error', 'Error loading scheduled jobs: ' + this.error.message, 'error');
        }
    }
    
    // Get email templates
    @wire(getEmailTemplates)
    wiredTemplates(result) {
        this.wiredTemplatesResult = result;
        if (result.data) {
            this.emailTemplates = result.data.map(template => ({
                label: template.Name,
                value: template.Id,
                description: template.Description || ''
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.emailTemplates = undefined;
            this.showToast('Error', 'Error loading email templates: ' + this.error.message, 'error');
        }
    }
    
    // Handle settings field change
    handleSettingsChange(event) {
        const { name, value, checked } = event.target;
        
        if (name === 'enableEmailNotifications' || name === 'enableChatterPosts') {
            this.settings[name + '__c'] = checked;
        } else {
            this.settings[name + '__c'] = value;
        }
    }
    
    // Save settings
    handleSaveSettings() {
        this.isLoading = true;
        
        saveSettings({ settings: this.settings })
            .then(result => {
                this.settings = { ...result };
                this.showToast('Success', 'Settings saved successfully', 'success');
                return refreshApex(this.wiredSettingsResult);
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error saving settings: ' + this.error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Run batch job now
    handleRunBatchNow() {
        this.isLoading = true;
        
        runBatchJob()
            .then(result => {
                this.showToast('Success', 'Batch job started with ID: ' + result, 'success');
                // Refresh stats after a delay to allow batch to process
                setTimeout(() => {
                    refreshApex(this.wiredStatsResult);
                }, 5000);
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error running batch job: ' + this.error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Schedule job
    handleScheduleJob() {
        this.isLoading = true;
        
        scheduleJob({
            jobName: this.jobName,
            hour: this.scheduledHour,
            minute: this.scheduledMinute
        })
            .then(result => {
                this.showToast('Success', 'Job scheduled successfully', 'success');
                return refreshApex(this.wiredJobsResult);
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error scheduling job: ' + this.error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Handle job name change
    handleJobNameChange(event) {
        this.jobName = event.target.value;
    }
    
    // Handle hour change
    handleHourChange(event) {
        this.scheduledHour = parseInt(event.target.value, 10);
    }
    
    // Handle minute change
    handleMinuteChange(event) {
        this.scheduledMinute = parseInt(event.target.value, 10);
    }
    
    // Delete scheduled job
    handleDeleteJob(event) {
        const jobId = event.target.dataset.id;
        this.isLoading = true;
        
        deleteScheduledJob({ jobId })
            .then(result => {
                this.showToast('Success', 'Job deleted successfully', 'success');
                return refreshApex(this.wiredJobsResult);
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error deleting job: ' + this.error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Refresh data
    handleRefreshData() {
        this.isLoading = true;
        
        Promise.all([
            refreshApex(this.wiredSettingsResult),
            refreshApex(this.wiredStatsResult),
            refreshApex(this.wiredJobsResult)
        ])
            .then(() => {
                this.showToast('Success', 'Data refreshed successfully', 'success');
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error', 'Error refreshing data: ' + this.error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
    
    // Handle tab switch
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
    
    // Get formatted date
    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return '';
        
        const dateTime = new Date(dateTimeStr);
        return dateTime.toLocaleString();
    }
    
    // Get hours options for combobox
    get hoursOptions() {
        let options = [];
        for (let i = 0; i < 24; i++) {
            options.push({
                label: i.toString().padStart(2, '0') + ':00',
                value: i
            });
        }
        return options;
    }
    
    // Get minutes options for combobox
    get minutesOptions() {
        let options = [];
        for (let i = 0; i < 60; i += 5) {
            options.push({
                label: i.toString().padStart(2, '0'),
                value: i
            });
        }
        return options;
    }
    
    // Get upcoming birthday count from stats
    get upcomingBirthdayCount() {
        return this.stats ? this.stats.upcomingBirthdaysCount : 0;
    }
    
    // Get reminders sent today from stats
    get remindersSentToday() {
        return this.stats ? this.stats.remindersSentToday : 0;
    }
    
    // Get reminders sent this month from stats
    get remindersSentThisMonth() {
        return this.stats ? this.stats.remindersSentThisMonth : 0;
    }
    
    // Get total reminders from stats
    get totalReminders() {
        return this.stats ? this.stats.totalReminders : 0;
    }
}
