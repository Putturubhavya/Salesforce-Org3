public with sharing class BeatTriggerHandler {
    /**
     * @description Populates Geography__c from the related Employee__c record when an Employee is assigned to a Beat.
     * @param newBeats List of new or updated Beat__c records (Trigger.new)
     * @param oldMap Map of previous Beat__c records (Trigger.oldMap), null on insert
     */
    public static void populateGeographyFromEmployee(List<Beat__c> newBeats, Map<Id, Beat__c> oldMap) {
        Set<Id> employeeIds = new Set<Id>();

        for (Beat__c beat : newBeats) {
            Boolean isInsert = (oldMap == null);
            Boolean empChanged = !isInsert && (beat.Beat_Assigned_To__c != oldMap.get(beat.Id).Beat_Assigned_To__c);

            // Populate when Employee is assigned on insert, or when assigned employee changes, or if geography is missing
            if (beat.Beat_Assigned_To__c != null && (isInsert || empChanged || beat.Geography__c == null)) {
                employeeIds.add(beat.Beat_Assigned_To__c);
            }
        }

        if (employeeIds.isEmpty()) {
            return;
        }

        Map<Id, Employee__c> employeeMap = new Map<Id, Employee__c>([
            SELECT Id, Geography__c 
            FROM Employee__c 
            WHERE Id IN :employeeIds
        ]);

        for (Beat__c beat : newBeats) {
            if (beat.Beat_Assigned_To__c != null && employeeMap.containsKey(beat.Beat_Assigned_To__c)) {
                Employee__c emp = employeeMap.get(beat.Beat_Assigned_To__c);
                if (emp.Geography__c != null) {
                    beat.Geography__c = emp.Geography__c;
                }
            }
        }
    }
}