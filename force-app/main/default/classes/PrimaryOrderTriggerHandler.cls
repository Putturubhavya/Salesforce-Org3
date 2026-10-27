public without sharing class PrimaryOrderTriggerHandler {
    
    // 1. Bidirectional status synchronization
    public static void handleBefore(List<Primary_Order__c> newList, Map<Id, Primary_Order__c> oldMap) {
        for (Primary_Order__c po : newList) {
            Primary_Order__c oldPo = (oldMap != null && oldMap.containsKey(po.Id)) ? oldMap.get(po.Id) : null;
            
            // If Approval_Status__c was updated to Approved
            if (po.Approval_Status__c == 'Approved' && (oldPo == null || oldPo.Approval_Status__c != 'Approved')) {
                if (po.Status__c != 'Delivered') {
                    po.Status__c = 'Approved';
                }
            }
            // If Approval_Status__c was updated to Rejected
            else if (po.Approval_Status__c == 'Rejected' && (oldPo == null || oldPo.Approval_Status__c != 'Rejected')) {
                po.Status__c = 'Rejected';
            }
            // If Status__c was updated to Approved
            else if (po.Status__c == 'Approved' && (oldPo == null || oldPo.Status__c != 'Approved')) {
                po.Approval_Status__c = 'Approved';
            }
            // If Status__c was updated to Rejected
            else if (po.Status__c == 'Rejected' && (oldPo == null || oldPo.Status__c != 'Rejected')) {
                po.Approval_Status__c = 'Rejected';
            }
        }
    }
    
    // 2. Submit to Approval Process & Send Bell Notification
    public static void handleAfter(List<Primary_Order__c> newList, Map<Id, Primary_Order__c> oldMap) {
        List<Id> ordersToSubmit = new List<Id>();
        
        for (Primary_Order__c po : newList) {
            Primary_Order__c oldPo = (oldMap != null && oldMap.containsKey(po.Id)) ? oldMap.get(po.Id) : null;
            if (po.Status__c == 'Submitted' && (oldPo == null || oldPo.Status__c != 'Submitted')) {
                ordersToSubmit.add(po.Id);
            }
        }
        
        if (!ordersToSubmit.isEmpty()) {
            submitForApprovalAndNotify(ordersToSubmit);
        }
    }
    
    private static void submitForApprovalAndNotify(List<Id> orderIds) {
        // Query order details with Distributor Name
        List<Primary_Order__c> orders = [
            SELECT Id, Name, Total_Cases__c, Total_Amount__c, Distributor__r.Name, Distributor_Officer__c
            FROM Primary_Order__c
            WHERE Id IN :orderIds
        ];
        
        // Find notification type
        Id notifTypeId;
        try {
            CustomNotificationType cn = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Britannia_Approval_Notification' LIMIT 1];
            notifTypeId = cn.Id;
        } catch (Exception e) {
            System.debug('Custom notification type not found: ' + e.getMessage());
        }
        
        // Approver User ID (Putturu Bhavya)
        Id bhavyaUserId;
        try {
            User u = [SELECT Id FROM User WHERE Username LIKE 'bhavyaputturu%' AND IsActive = true LIMIT 1];
            bhavyaUserId = u.Id;
        } catch (Exception e) {
            bhavyaUserId = UserInfo.getUserId();
        }
        
        for (Primary_Order__c po : orders) {
            // Check if already in approval
            List<ProcessInstance> activeProcesses = [
                SELECT Id FROM ProcessInstance 
                WHERE TargetObjectId = :po.Id AND Status = 'Pending' LIMIT 1
            ];
            
            if (activeProcesses.isEmpty()) {
                try {
                    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                    req.setComments('Primary Order submitted for Distributor Officer approval.');
                    req.setObjectId(po.Id);
                    req.setSubmitterId(UserInfo.getUserId());
                    req.setProcessDefinitionNameOrId('Primary_Order_Approval');
                    Approval.ProcessResult result = Approval.process(req);
                } catch (Exception ex) {
                    System.debug('Approval submit exception: ' + ex.getMessage());
                }
            }
            
            // Send Bell Notification to Putturu Bhavya
            if (notifTypeId != null && bhavyaUserId != null) {
                try {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('Primary Order Pending Approval: ' + po.Name);
                    String distName = po.Distributor__r != null ? po.Distributor__r.Name : 'Distributor';
                    notification.setBody('Primary Order for ' + distName + ' (' + (po.Total_Cases__c != null ? po.Total_Cases__c : 0) + ' Cases, ₹' + (po.Total_Amount__c != null ? po.Total_Amount__c : 0) + ') is awaiting your approval. Click to view and approve.');
                    notification.setNotificationTypeId(notifTypeId);
                    notification.setTargetId(po.Id);
                    notification.send(new Set<String>{ String.valueOf(bhavyaUserId) });
                } catch (Exception ex) {
                    System.debug('Notification send error: ' + ex.getMessage());
                }
            }
        }
    }
}