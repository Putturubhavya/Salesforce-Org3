@isTest
private class OutletTriggerTest {
    @TestSetup
    static void setupData() {
        Geography__c geo = new Geography__c(Name = 'Test Outlet Geography');
        insert geo;

        Employee__c emp = new Employee__c(
            Geography__c = geo.Id,
            Active__c = true
        );
        insert emp;

        Beat__c beat = new Beat__c(
            Name = 'Test Outlet Beat',
            Beat_Assigned_To__c = emp.Id,
            Geography__c = geo.Id,
            Frequency__c = 'Daily'
        );
        insert beat;
    }

    @isTest
    static void testInsertSingleOutletPopulatesGeography() {
        Beat__c beat = [SELECT Id, Geography__c FROM Beat__c LIMIT 1];

        Test.startTest();
        Outlet__c outlet = new Outlet__c(
            Name = 'Single Test Outlet',
            Beat__c = beat.Id
        );
        insert outlet;
        Test.stopTest();

        Outlet__c insertedOutlet = [SELECT Id, Beat__c, Geography__c FROM Outlet__c WHERE Id = :outlet.Id];
        System.assertEquals(beat.Geography__c, insertedOutlet.Geography__c, 'Geography should be auto-populated from Beat on insert');
    }

    @isTest
    static void testInsertBulkOutletsPopulatesGeography() {
        Beat__c beat = [SELECT Id, Geography__c FROM Beat__c LIMIT 1];

        List<Outlet__c> outlets = new List<Outlet__c>();
        for (Integer i = 0; i < 100; i++) {
            outlets.add(new Outlet__c(
                Name = 'Bulk Test Outlet ' + i,
                Beat__c = beat.Id
            ));
        }

        Test.startTest();
        insert outlets;
        Test.stopTest();

        List<Outlet__c> insertedOutlets = [SELECT Id, Geography__c FROM Outlet__c WHERE Beat__c = :beat.Id];
        System.assertEquals(100, insertedOutlets.size(), 'Should have inserted 100 outlets');
        for (Outlet__c o : insertedOutlets) {
            System.assertEquals(beat.Geography__c, o.Geography__c, 'Every outlet must have the correct Geography');
        }
    }

    @isTest
    static void testUpdateOutletBeatUpdatesGeography() {
        Geography__c geo2 = new Geography__c(Name = 'Second Test Geography');
        insert geo2;

        Beat__c beat2 = new Beat__c(
            Name = 'Second Beat',
            Geography__c = geo2.Id,
            Frequency__c = 'Weekly'
        );
        insert beat2;

        Beat__c beat1 = [SELECT Id, Geography__c FROM Beat__c WHERE Name = 'Test Outlet Beat' LIMIT 1];

        Outlet__c outlet = new Outlet__c(
            Name = 'Update Test Outlet',
            Beat__c = beat1.Id
        );
        insert outlet;

        Test.startTest();
        outlet.Beat__c = beat2.Id;
        update outlet;
        Test.stopTest();

        Outlet__c updatedOutlet = [SELECT Id, Geography__c FROM Outlet__c WHERE Id = :outlet.Id];
        System.assertEquals(geo2.Id, updatedOutlet.Geography__c, 'Geography should update when Beat is changed');
    }

    @isTest
    static void testControllerGetBeatGeography() {
        Beat__c beat = [SELECT Id, Geography__c FROM Beat__c LIMIT 1];

        Test.startTest();
        String geoId = BeatController.getBeatGeography(beat.Id);
        String nullGeoId = BeatController.getBeatGeography(null);
        Test.stopTest();

        System.assertEquals(beat.Geography__c, geoId, 'Controller should return correct Beat geography');
        System.assertEquals(null, nullGeoId, 'Controller should return null for null input');
    }
}