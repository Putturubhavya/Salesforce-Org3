trigger SalesOrderTrigger on Sales_Order__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        SalesOrderTriggerHandler.syncToSecondaryOrder(Trigger.new);
    }
}