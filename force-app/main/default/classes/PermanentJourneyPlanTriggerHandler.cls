public with sharing class PermanentJourneyPlanTriggerHandler {
    /**
     * @description Populates Employee__c and Approver__c on Permanent Journey Plan before insert/update.
     */
    public static void populateEmployeeAndApprover(List<Permanent_Journey_Plan__c> newPJPs, Map<Id, Permanent_Journey_Plan__c> oldMap) {
        Set<Id> beatIds = new Set<Id>();

        for (Permanent_Journey_Plan__c pjp : newPJPs) {
            Boolean isInsert = (oldMap == null);
            Boolean beatChanged = !isInsert && (pjp.Beat__c != oldMap.get(pjp.Id).Beat__c);

            if (pjp.Beat__c != null && (isInsert || beatChanged || pjp.Employee__c == null)) {
                beatIds.add(pjp.Beat__c);
            }
        }

        if (!beatIds.isEmpty()) {
            Map<Id, Beat__c> beatMap = new Map<Id, Beat__c>([
                SELECT Id, Beat_Assigned_To__c 
                FROM Beat__c 
                WHERE Id IN :beatIds
            ]);

            for (Permanent_Journey_Plan__c pjp : newPJPs) {
                Boolean isInsert = (oldMap == null);
                Boolean beatChanged = !isInsert && (pjp.Beat__c != oldMap.get(pjp.Id).Beat__c);

                if (pjp.Beat__c != null && beatMap.containsKey(pjp.Beat__c)) {
                    Beat__c beat = beatMap.get(pjp.Beat__c);
                    if (beat.Beat_Assigned_To__c != null && (isInsert || beatChanged || pjp.Employee__c == null)) {
                        pjp.Employee__c = beat.Beat_Assigned_To__c;
                    }
                }
            }
        }

        // Now populate Approver__c from Employee__c.Reporting_Manager__r.Employee_Name__c
        Set<Id> empIds = new Set<Id>();
        for (Permanent_Journey_Plan__c pjp : newPJPs) {
            if (pjp.Employee__c != null) {
                empIds.add(pjp.Employee__c);
            }
        }

        if (!empIds.isEmpty()) {
            Map<Id, Employee__c> empMap = new Map<Id, Employee__c>([
                SELECT Id, Reporting_Manager__c, Reporting_Manager__r.Employee_Name__c 
                FROM Employee__c 
                WHERE Id IN :empIds
            ]);

            for (Permanent_Journey_Plan__c pjp : newPJPs) {
                if (pjp.Employee__c != null && empMap.containsKey(pjp.Employee__c)) {
                    Employee__c emp = empMap.get(pjp.Employee__c);
                    if (emp.Reporting_Manager__c != null && emp.Reporting_Manager__r.Employee_Name__c != null) {
                        pjp.Approver__c = emp.Reporting_Manager__r.Employee_Name__c;
                    }
                }
            }
        }
    }

    /**
     * @description Syncs the approval status to the related Employee__c.PJP__c field.
     */
    public static void syncApprovalStatusToEmployee(List<Permanent_Journey_Plan__c> newPJPs, Map<Id, Permanent_Journey_Plan__c> oldMap) {
        Map<Id, String> empIdToStatusMap = new Map<Id, String>();

        for (Permanent_Journey_Plan__c pjp : newPJPs) {
            Permanent_Journey_Plan__c oldPjp = oldMap != null ? oldMap.get(pjp.Id) : null;
            Boolean statusChanged = (oldPjp == null) || (pjp.Approval_Status__c != oldPjp.Approval_Status__c);

            if (statusChanged && pjp.Employee__c != null && String.isNotBlank(pjp.Approval_Status__c)) {
                empIdToStatusMap.put(pjp.Employee__c, pjp.Approval_Status__c);
            }
        }

        if (empIdToStatusMap.isEmpty()) {
            return;
        }

        List<Employee__c> empsToUpdate = [
            SELECT Id, PJP__c 
            FROM Employee__c 
            WHERE Id IN :empIdToStatusMap.keySet()
        ];

        for (Employee__c emp : empsToUpdate) {
            String newStatus = empIdToStatusMap.get(emp.Id);
            emp.PJP__c = newStatus;
        }

        update empsToUpdate;
    }

    /**
     * @description Populates Approved_Date__c on approval and Approval_Rejection_Reason__c on rejection.
     */
    public static void handleApprovalDatesAndReasons(List<Permanent_Journey_Plan__c> newPJPs, Map<Id, Permanent_Journey_Plan__c> oldMap) {
        Set<Id> rejectedPjpIds = new Set<Id>();

        for (Permanent_Journey_Plan__c pjp : newPJPs) {
            Permanent_Journey_Plan__c oldPjp = (oldMap != null) ? oldMap.get(pjp.Id) : null;
            Boolean isApproved = (pjp.Approval_Status__c == 'Approved');
            Boolean isRejected = (pjp.Approval_Status__c == 'Rejected');
            Boolean isPending = (pjp.Approval_Status__c == 'Pending');

            if (isApproved) {
                if (pjp.Approved_Date__c == null) {
                    pjp.Approved_Date__c = Date.today();
                }
                pjp.Approval_Rejection_Reason__c = null;
            } else if (isRejected) {
                pjp.Approved_Date__c = null;
                if (pjp.Id != null && String.isBlank(pjp.Approval_Rejection_Reason__c)) {
                    rejectedPjpIds.add(pjp.Id);
                }
            } else if (isPending) {
                pjp.Approved_Date__c = null;
                pjp.Approval_Rejection_Reason__c = null;
            }
        }

        if (!rejectedPjpIds.isEmpty()) {
            Map<Id, String> rejectionCommentMap = new Map<Id, String>();
            for (ProcessInstanceStep step : [
                SELECT ProcessInstance.TargetObjectId, Comments, Actor.Name, StepStatus, CreatedDate 
                FROM ProcessInstanceStep 
                WHERE ProcessInstance.TargetObjectId IN :rejectedPjpIds 
                  AND StepStatus = 'Rejected' 
                ORDER BY CreatedDate DESC
            ]) {
                Id targetId = step.ProcessInstance.TargetObjectId;
                if (!rejectionCommentMap.containsKey(targetId)) {
                    String reason = String.isNotBlank(step.Comments) 
                        ? step.Comments 
                        : ('Rejected by ' + (step.Actor != null ? step.Actor.Name : 'Approver'));
                    rejectionCommentMap.put(targetId, reason);
                }
            }

            for (Permanent_Journey_Plan__c pjp : newPJPs) {
                if (pjp.Approval_Status__c == 'Rejected' && String.isBlank(pjp.Approval_Rejection_Reason__c)) {
                    if (rejectionCommentMap.containsKey(pjp.Id)) {
                        pjp.Approval_Rejection_Reason__c = rejectionCommentMap.get(pjp.Id);
                    } else {
                        pjp.Approval_Rejection_Reason__c = 'Rejected by Approver';
                    }
                }
            }
        }
    }
}