trigger OutletTrigger on Outlet__c (before insert, before update) {
    OutletTriggerHandler.populateGeographyFromBeat(Trigger.new, Trigger.oldMap);
}