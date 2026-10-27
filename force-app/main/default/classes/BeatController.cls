public with sharing class BeatController {
    @AuraEnabled(cacheable=true)
    public static String getEmployeeGeography(Id employeeId) {
        if (employeeId == null) return null;
        List<Employee__c> emps = [SELECT Id, Geography__c FROM Employee__c WHERE Id = :employeeId LIMIT 1];
        return (!emps.isEmpty() && emps[0].Geography__c != null) ? emps[0].Geography__c : null;
    }

    @AuraEnabled(cacheable=true)
    public static String getBeatGeography(Id beatId) {
        if (beatId == null) return null;
        List<Beat__c> beats = [SELECT Id, Geography__c FROM Beat__c WHERE Id = :beatId LIMIT 1];
        return (!beats.isEmpty() && beats[0].Geography__c != null) ? beats[0].Geography__c : null;
    }

    @AuraEnabled(cacheable=true)
    public static String getBeatEmployee(Id beatId) {
        if (beatId == null) return null;
        List<Beat__c> beats = [SELECT Id, Beat_Assigned_To__c FROM Beat__c WHERE Id = :beatId LIMIT 1];
        return (!beats.isEmpty() && beats[0].Beat_Assigned_To__c != null) ? beats[0].Beat_Assigned_To__c : null;
    }

    /**
     * @description Submits a Permanent Journey Plan for Approval.
     */
    @AuraEnabled
    public static String submitPjpForApproval(Id pjpId) {
        try {
            Permanent_Journey_Plan__c pjp = [
                SELECT Id, Approver__c, Approval_Status__c 
                FROM Permanent_Journey_Plan__c 
                WHERE Id = :pjpId 
                LIMIT 1
            ];

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(pjpId);
            req.setComments('Submitted for Approval');
            Approval.ProcessResult result = Approval.process(req);

            if (result.isSuccess()) {
                return 'SUCCESS';
            } else {
                return 'Submission failed';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Directly Approves or Rejects the pending approval request for a PJP.
     */
    @AuraEnabled
    public static String processPjpApproval(Id pjpId, String action, String comments) {
        try {
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id 
                FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :pjpId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            if (workItems.isEmpty()) {
                // If not in standard work item, update field directly
                Permanent_Journey_Plan__c pjp = new Permanent_Journey_Plan__c(
                    Id = pjpId,
                    Approval_Status__c = (action == 'Approve' ? 'Approved' : 'Rejected')
                );
                if (action == 'Approve') {
                    pjp.Approved_Date__c = Date.today();
                    pjp.Approval_Rejection_Reason__c = null;
                } else {
                    pjp.Approved_Date__c = null;
                    pjp.Approval_Rejection_Reason__c = String.isNotBlank(comments) ? comments : 'Rejected by Approver';
                }
                update pjp;
                return 'SUCCESS';
            }

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItems[0].Id);
            req.setAction(action); // 'Approve' or 'Reject'
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }
            Approval.ProcessResult result = Approval.process(req);

            if (result.isSuccess()) {
                return 'SUCCESS';
            } else {
                return 'Approval action failed';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Returns approval details for a PJP.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPjpApprovalDetails(Id pjpId) {
        Map<String, Object> res = new Map<String, Object>();
        if (pjpId == null) return res;

        Permanent_Journey_Plan__c pjp = [
            SELECT Id, Approval_Status__c, Approver__c, Approver__r.Name, Employee__r.Name, Beat__r.Name 
            FROM Permanent_Journey_Plan__c 
            WHERE Id = :pjpId 
            LIMIT 1
        ];

        res.put('status', pjp.Approval_Status__c);
        res.put('approverName', pjp.Approver__r != null ? pjp.Approver__r.Name : '');
        res.put('approverId', pjp.Approver__c);

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id, ActorId, Actor.Name 
            FROM ProcessInstanceWorkitem 
            WHERE ProcessInstance.TargetObjectId = :pjpId 
            LIMIT 1
        ];

        res.put('hasPendingWorkItem', !workItems.isEmpty());
        if (!workItems.isEmpty()) {
            res.put('currentActorName', workItems[0].Actor.Name);
        }

        return res;
    }
}