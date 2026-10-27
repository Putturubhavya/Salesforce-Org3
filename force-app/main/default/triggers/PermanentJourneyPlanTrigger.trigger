trigger PermanentJourneyPlanTrigger on Permanent_Journey_Plan__c (before insert, before update, after update) {
    if (Trigger.isBefore) {
        PermanentJourneyPlanTriggerHandler.populateEmployeeAndApprover(Trigger.new, Trigger.oldMap);
        PermanentJourneyPlanTriggerHandler.handleApprovalDatesAndReasons(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        PermanentJourneyPlanTriggerHandler.syncApprovalStatusToEmployee(Trigger.new, Trigger.oldMap);
    }
}