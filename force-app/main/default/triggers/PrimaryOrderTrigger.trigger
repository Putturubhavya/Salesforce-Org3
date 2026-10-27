trigger PrimaryOrderTrigger on Primary_Order__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        PrimaryOrderTriggerHandler.handleBefore(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter) {
        PrimaryOrderTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}