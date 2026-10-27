public with sharing class SalesOrderTriggerHandler {
    
    /**
     * @description When a Sales Order is created in SFA, automatically synchronize it into the DMS Secondary Order object
     * and assign the Outlet's Distributor and Sales Representative.
     */
    public static void syncToSecondaryOrder(List<Sales_Order__c> newOrders) {
        Set<Id> outletIds = new Set<Id>();
        for (Sales_Order__c so : newOrders) {
            if (so.Outlet_Name__c != null) {
                outletIds.add(so.Outlet_Name__c);
            }
        }

        if (outletIds.isEmpty()) return;

        Map<Id, Outlet__c> outletMap = new Map<Id, Outlet__c>([
            SELECT Id, Name, Distributor__c, Beat__c,
                   Beat__r.Distributor_Lookup__c,
                   Beat__r.Beat_Assigned_To__c,
                   Beat__r.Beat_Assigned_To__r.Distributor__c
            FROM Outlet__c 
            WHERE Id IN :outletIds
        ]);

        // Default distributor in case outlet and beat don't have one
        Id defaultDistId = null;
        List<Distributor__c> defaultDists = [
            SELECT Id FROM Distributor__c 
            WHERE Status__c = 'Active' 
            ORDER BY CreatedDate ASC 
            LIMIT 1
        ];
        if (!defaultDists.isEmpty()) {
            defaultDistId = defaultDists[0].Id;
        }

        List<Secondary_Order__c> secondaryOrdersToInsert = new List<Secondary_Order__c>();
        Map<Integer, Sales_Order__c> indexToSalesOrder = new Map<Integer, Sales_Order__c>();
        List<Outlet__c> outletsToUpdate = new List<Outlet__c>();

        Integer idx = 0;
        for (Sales_Order__c so : newOrders) {
            Outlet__c outlet = outletMap.get(so.Outlet_Name__c);
            Id distId = null;
            Id beatId = null;
            Id empId = null;

            if (outlet != null) {
                beatId = outlet.Beat__c;
                if (outlet.Distributor__c != null) {
                    distId = outlet.Distributor__c;
                } else if (outlet.Beat__r != null && outlet.Beat__r.Distributor_Lookup__c != null) {
                    distId = outlet.Beat__r.Distributor_Lookup__c;
                } else if (outlet.Beat__r != null && outlet.Beat__r.Beat_Assigned_To__r != null && outlet.Beat__r.Beat_Assigned_To__r.Distributor__c != null) {
                    distId = outlet.Beat__r.Beat_Assigned_To__r.Distributor__c;
                }

                if (outlet.Beat__r != null && outlet.Beat__r.Beat_Assigned_To__c != null) {
                    empId = outlet.Beat__r.Beat_Assigned_To__c;
                }

                // If outlet didn't have Distributor__c, set it now
                if (outlet.Distributor__c == null && distId != null) {
                    outlet.Distributor__c = distId;
                    outletsToUpdate.add(new Outlet__c(Id = outlet.Id, Distributor__c = distId));
                }
            }

            if (distId == null && so.Distributor__c != null) {
                distId = so.Distributor__c;
            }

            if (distId == null) {
                distId = defaultDistId;
            }

            Secondary_Order__c secOrder = new Secondary_Order__c(
                Outlet__c = so.Outlet_Name__c,
                Distributor__c = distId,
                Employee__c = empId,
                Beat__c = beatId,
                Order_Date__c = Date.today(),
                Status__c = 'Submitted',
                Total_Quantity__c = so.Total_Quantity__c != null ? so.Total_Quantity__c : 1,
                Total_Amount__c = so.Total_Amount__c != null ? so.Total_Amount__c : 0,
                Remarks__c = 'Order placed via SFA Mobile App (' + so.Name + ')'
            );
            secondaryOrdersToInsert.add(secOrder);
            indexToSalesOrder.put(idx, so);
            idx++;
        }

        if (!secondaryOrdersToInsert.isEmpty()) {
            insert secondaryOrdersToInsert;

            // Now create item lines
            List<Secondary_Order_Item__c> itemsToInsert = new List<Secondary_Order_Item__c>();
            for (Integer i = 0; i < secondaryOrdersToInsert.size(); i++) {
                Secondary_Order__c createdSO = secondaryOrdersToInsert[i];
                Sales_Order__c original = indexToSalesOrder.get(i);

                Decimal qty = original.Total_Quantity__c != null ? original.Total_Quantity__c : 1;
                Decimal tot = original.Total_Amount__c != null ? original.Total_Amount__c : 0;
                Decimal price = qty > 0 ? (tot / qty) : 0;

                itemsToInsert.add(new Secondary_Order_Item__c(
                    Secondary_Order__c = createdSO.Id,
                    Product__c = original.Product__c,
                    Quantity__c = qty,
                    Price__c = price,
                    Total__c = tot,
                    Scheme_Applied__c = original.Scheme__c != null ? 'Promo Scheme' : 'Standard'
                ));
            }

            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
            }
        }

        // Asynchronously or safely update outlets that were missing Distributor__c
        if (!outletsToUpdate.isEmpty()) {
            try {
                update outletsToUpdate;
            } catch (Exception e) {
                System.debug('Outlet distributor update notice: ' + e.getMessage());
            }
        }
    }
}