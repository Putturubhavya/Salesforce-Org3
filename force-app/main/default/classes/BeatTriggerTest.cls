@isTest
private class BeatTriggerTest {
    @TestSetup
    static void setupData() {
        Geography__c geo = new Geography__c(Name = 'Test Bangalore Geography');
        insert geo;

        Employee__c emp = new Employee__c(
            Geography__c = geo.Id,
            Active__c = true
        );
        insert emp;
    }

    @isTest
    static void testInsertBeatWithEmployeePopulatesGeography() {
        Employee__c emp = [SELECT Id, Geography__c FROM Employee__c LIMIT 1];

        Test.startTest();
        Beat__c beat = new Beat__c(
            Name = 'Test Beat 1',
            Beat_Assigned_To__c = emp.Id,
            Frequency__c = 'Daily',
            Active__c = true
        );
        insert beat;
        Test.stopTest();

        Beat__c insertedBeat = [SELECT Id, Name, Beat_Assigned_To__c, Geography__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(emp.Geography__c, insertedBeat.Geography__c, 'Geography should be auto-populated from Employee on insert');
    }

    @isTest
    static void testUpdateBeatEmployeeUpdatesGeography() {
        Geography__c geo1 = [SELECT Id FROM Geography__c LIMIT 1];
        Geography__c geo2 = new Geography__c(Name = 'Test Mysore Geography');
        insert geo2;

        Employee__c emp2 = new Employee__c(
            Geography__c = geo2.Id,
            Active__c = true
        );
        insert emp2;

        Beat__c beat = new Beat__c(
            Name = 'Test Beat 2',
            Geography__c = geo1.Id,
            Frequency__c = 'Weekly'
        );
        insert beat;

        Test.startTest();
        beat.Beat_Assigned_To__c = emp2.Id;
        update beat;
        Test.stopTest();

        Beat__c updatedBeat = [SELECT Id, Geography__c FROM Beat__c WHERE Id = :beat.Id];
        System.assertEquals(geo2.Id, updatedBeat.Geography__c, 'Geography should be updated when assigned employee changes');
    }

    @isTest
    static void testControllerGetEmployeeGeography() {
        Employee__c emp = [SELECT Id, Geography__c FROM Employee__c LIMIT 1];

        Test.startTest();
        String geoId = BeatController.getEmployeeGeography(emp.Id);
        String nullGeoId = BeatController.getEmployeeGeography(null);
        Test.stopTest();

        System.assertEquals(emp.Geography__c, geoId, 'Controller should return correct geography ID');
        System.assertEquals(null, nullGeoId, 'Controller should return null for null input');
    }
}