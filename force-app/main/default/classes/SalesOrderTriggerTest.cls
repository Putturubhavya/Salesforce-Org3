@isTest
private class SalesOrderTriggerTest {

    @isTest
    static void testSalesOrderSyncToSecondaryOrder() {
        // Create test Distributor
        Distributor__c dist = new Distributor__c(
            Name = 'Test DMS Distributor',
            Distributor_Code__c = 'DIST-TEST-99',
            Status__c = 'Active',
            Enable_DMS__c = true
        );
        insert dist;

        // Create test Outlet
        Outlet__c outlet = new Outlet__c(
            Name = 'Test Retail Outlet',
            Distributor__c = dist.Id
        );
        insert outlet;

        // Create test Sales Order
        Sales_Order__c so = new Sales_Order__c(
            Outlet_Name__c = outlet.Id,
            Total_Quantity__c = 10,
            Total_Amount__c = 500.00
        );
        
        Test.startTest();
        insert so;
        Test.stopTest();

        // Verify Secondary Order was created
        List<Secondary_Order__c> secOrders = [
            SELECT Id, Outlet__c, Distributor__c, Status__c, Total_Quantity__c, Total_Amount__c 
            FROM Secondary_Order__c 
            WHERE Outlet__c = :outlet.Id
        ];
        System.assertEquals(1, secOrders.size(), 'Secondary Order should be automatically created');
        System.assertEquals(dist.Id, secOrders[0].Distributor__c, 'Distributor should match outlet distributor');
        System.assertEquals('Submitted', secOrders[0].Status__c, 'Status should be Submitted');

        // Verify Secondary Order Item
        List<Secondary_Order_Item__c> items = [
            SELECT Id, Quantity__c, Total__c 
            FROM Secondary_Order_Item__c 
            WHERE Secondary_Order__c = :secOrders[0].Id
        ];
        System.assertEquals(1, items.size(), 'Secondary Order Item should be created');
        System.assertEquals(10, items[0].Quantity__c, 'Quantity should match');
    }
}