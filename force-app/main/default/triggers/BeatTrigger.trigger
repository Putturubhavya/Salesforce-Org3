trigger BeatTrigger on Beat__c (before insert, before update) {
    BeatTriggerHandler.populateGeographyFromEmployee(Trigger.new, Trigger.oldMap);
}