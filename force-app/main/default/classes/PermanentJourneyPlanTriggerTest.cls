@isTest
private class PermanentJourneyPlanTriggerTest {
    @TestSetup
    static void setupData() {
        Geography__c geo = new Geography__c(Name = 'Test PJP Geography');
        insert geo;

        Employee__c emp = new Employee__c(
            Geography__c = geo.Id,
            Active__c = true
        );
        insert emp;

        Beat__c beat = new Beat__c(
            Name = 'Test PJP Beat',
            Beat_Assigned_To__c = emp.Id,
            Geography__c = geo.Id,
            Frequency__c = 'Daily'
        );
        insert beat;
    }

    @isTest
    static void testInsertSinglePJPPopulatesEmployee() {
        Beat__c beat = [SELECT Id, Beat_Assigned_To__c FROM Beat__c LIMIT 1];

        Test.startTest();
        Permanent_Journey_Plan__c pjp = new Permanent_Journey_Plan__c(
            Name = 'Single Test PJP',
            Beat__c = beat.Id
        );
        insert pjp;
        Test.stopTest();

        Permanent_Journey_Plan__c insertedPjp = [SELECT Id, Beat__c, Employee__c FROM Permanent_Journey_Plan__c WHERE Id = :pjp.Id];
        System.assertEquals(beat.Beat_Assigned_To__c, insertedPjp.Employee__c, 'Employee should be auto-populated from Beat on insert');
    }

    @isTest
    static void testInsertBulkPJPsPopulatesEmployee() {
        Beat__c beat = [SELECT Id, Beat_Assigned_To__c FROM Beat__c LIMIT 1];

        List<Permanent_Journey_Plan__c> pjps = new List<Permanent_Journey_Plan__c>();
        for (Integer i = 0; i < 100; i++) {
            pjps.add(new Permanent_Journey_Plan__c(
                Name = 'Bulk Test PJP ' + i,
                Beat__c = beat.Id
            ));
        }

        Test.startTest();
        insert pjps;
        Test.stopTest();

        List<Permanent_Journey_Plan__c> insertedPjps = [SELECT Id, Employee__c FROM Permanent_Journey_Plan__c WHERE Beat__c = :beat.Id];
        System.assertEquals(100, insertedPjps.size(), 'Should have inserted 100 PJPs');
        for (Permanent_Journey_Plan__c p : insertedPjps) {
            System.assertEquals(beat.Beat_Assigned_To__c, p.Employee__c, 'Every PJP must have the correct Employee');
        }
    }

    @isTest
    static void testUpdatePJPBeatUpdatesEmployee() {
        Geography__c geo = [SELECT Id FROM Geography__c LIMIT 1];
        Employee__c emp2 = new Employee__c(Active__c = true, Geography__c = geo.Id);
        insert emp2;

        Beat__c beat2 = new Beat__c(
            Name = 'Second PJP Beat',
            Beat_Assigned_To__c = emp2.Id,
            Geography__c = geo.Id,
            Frequency__c = 'Weekly'
        );
        insert beat2;

        Beat__c beat1 = [SELECT Id, Beat_Assigned_To__c FROM Beat__c WHERE Name = 'Test PJP Beat' LIMIT 1];

        Permanent_Journey_Plan__c pjp = new Permanent_Journey_Plan__c(
            Name = 'Update Test PJP',
            Beat__c = beat1.Id
        );
        insert pjp;

        Test.startTest();
        pjp.Beat__c = beat2.Id;
        update pjp;
        Test.stopTest();

        Permanent_Journey_Plan__c updatedPjp = [SELECT Id, Employee__c FROM Permanent_Journey_Plan__c WHERE Id = :pjp.Id];
        System.assertEquals(emp2.Id, updatedPjp.Employee__c, 'Employee should update when Beat is changed');
    }

    @isTest
    static void testControllerGetBeatEmployee() {
        Beat__c beat = [SELECT Id, Beat_Assigned_To__c FROM Beat__c LIMIT 1];

        Test.startTest();
        String empId = BeatController.getBeatEmployee(beat.Id);
        String nullEmpId = BeatController.getBeatEmployee(null);
        Test.stopTest();

        System.assertEquals(beat.Beat_Assigned_To__c, empId, 'Controller should return correct Beat employee');
        System.assertEquals(null, nullEmpId, 'Controller should return null for null input');
    }

    @isTest
    static void testApproverPopulationAndSync() {
        Geography__c geo = [SELECT Id FROM Geography__c LIMIT 1];
        
        // Manager employee pointing to current user
        Employee__c mgrEmp = new Employee__c(
            Geography__c = geo.Id,
            Active__c = true,
            Employee_Name__c = UserInfo.getUserId()
        );
        insert mgrEmp;

        // Subordinate employee pointing to mgrEmp
        Employee__c subEmp = new Employee__c(
            Geography__c = geo.Id,
            Active__c = true,
            Reporting_Manager__c = mgrEmp.Id
        );
        insert subEmp;

        Beat__c beat = new Beat__c(
            Name = 'Sub Beat',
            Beat_Assigned_To__c = subEmp.Id,
            Geography__c = geo.Id,
            Frequency__c = 'Daily'
        );
        insert beat;

        Test.startTest();
        Permanent_Journey_Plan__c pjp = new Permanent_Journey_Plan__c(
            Name = 'Test Approver PJP',
            Beat__c = beat.Id
        );
        insert pjp;

        Permanent_Journey_Plan__c insertedPjp = [
            SELECT Id, Employee__c, Approver__c, Approval_Status__c 
            FROM Permanent_Journey_Plan__c 
            WHERE Id = :pjp.Id
        ];
        System.assertEquals(subEmp.Id, insertedPjp.Employee__c);
        System.assertEquals(UserInfo.getUserId(), insertedPjp.Approver__c, 'Approver should be manager user');

        // Test status sync
        insertedPjp.Approval_Status__c = 'Approved';
        update insertedPjp;
        Test.stopTest();

        Employee__c updatedEmp = [SELECT Id, PJP__c FROM Employee__c WHERE Id = :subEmp.Id];
        System.assertEquals('Approved', updatedEmp.PJP__c, 'Employee PJP status should sync to Approved');

        Permanent_Journey_Plan__c approvedPjp = [SELECT Id, Approved_Date__c, Approval_Rejection_Reason__c FROM Permanent_Journey_Plan__c WHERE Id = :insertedPjp.Id];
        System.assertEquals(Date.today(), approvedPjp.Approved_Date__c, 'Approved Date should be set automatically to today');

        // Test BeatController methods
        Map<String, Object> details = BeatController.getPjpApprovalDetails(insertedPjp.Id);
        System.assertEquals('Approved', details.get('status'));

        String result = BeatController.processPjpApproval(insertedPjp.Id, 'Reject', 'Test rejection');
        System.assertEquals('SUCCESS', result);

        Permanent_Journey_Plan__c rejectedPjp = [SELECT Id, Approved_Date__c, Approval_Status__c, Approval_Rejection_Reason__c FROM Permanent_Journey_Plan__c WHERE Id = :insertedPjp.Id];
        System.assertEquals('Rejected', rejectedPjp.Approval_Status__c);
        System.assertEquals(null, rejectedPjp.Approved_Date__c);
        System.assert(String.isNotBlank(rejectedPjp.Approval_Rejection_Reason__c), 'Rejection reason should come automatically');
    }
}