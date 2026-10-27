public with sharing class OutletTriggerHandler {
    /**
     * @description Populates Geography__c from the related Beat__c record when an Outlet is assigned to a Beat.
     * Bulkified to safely handle 100+ records.
     * @param newOutlets List of new or updated Outlet__c records
     * @param oldMap Map of previous Outlet__c records (null on insert)
     */
    public static void populateGeographyFromBeat(List<Outlet__c> newOutlets, Map<Id, Outlet__c> oldMap) {
        Set<Id> beatIds = new Set<Id>();

        for (Outlet__c outlet : newOutlets) {
            Boolean isInsert = (oldMap == null);
            Boolean beatChanged = !isInsert && (outlet.Beat__c != oldMap.get(outlet.Id).Beat__c);

            if (outlet.Beat__c != null && (isInsert || beatChanged || outlet.Geography__c == null)) {
                beatIds.add(outlet.Beat__c);
            }
        }

        if (beatIds.isEmpty()) {
            return;
        }

        Map<Id, Beat__c> beatMap = new Map<Id, Beat__c>([
            SELECT Id, Geography__c 
            FROM Beat__c 
            WHERE Id IN :beatIds
        ]);

        for (Outlet__c outlet : newOutlets) {
            if (outlet.Beat__c != null && beatMap.containsKey(outlet.Beat__c)) {
                Beat__c beat = beatMap.get(outlet.Beat__c);
                if (beat.Geography__c != null) {
                    outlet.Geography__c = beat.Geography__c;
                }
            }
        }
    }
}