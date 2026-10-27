({
    handleClose: function(component, event, helper) {
        var dismiss = $A.get("e.force:closeQuickAction");
        if (dismiss) {
            dismiss.fire();
        }
        var navEvent = $A.get("e.force:navigateToObjectHome");
        if (navEvent) {
            navEvent.setParams({
                "scope": "Beat__c"
            });
            navEvent.fire();
        }
    }
})