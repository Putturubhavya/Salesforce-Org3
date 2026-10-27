trigger ReturnTrigger on Return__c (after insert, after update) {
    if (Trigger.isAfter) {
        ReturnTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}