import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import submitPjpForApproval from '@salesforce/apex/BeatController.submitPjpForApproval';
import processPjpApproval from '@salesforce/apex/BeatController.processPjpApproval';
import getPjpApprovalDetails from '@salesforce/apex/BeatController.getPjpApprovalDetails';

const FIELDS = [
    'Permanent_Journey_Plan__c.Approval_Status__c',
    'Permanent_Journey_Plan__c.Approver__c',
    'Permanent_Journey_Plan__c.Employee__c'
];

export default class PjpApprovalCard extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track approvalDetails = {};

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.loadDetails();
        }
    }

    connectedCallback() {
        this.loadDetails();
    }

    loadDetails() {
        if (!this.recordId) return;
        getPjpApprovalDetails({ pjpId: this.recordId })
            .then(res => {
                this.approvalDetails = res || {};
            })
            .catch(err => {
                console.error('Error fetching approval details', err);
            });
    }

    get statusLabel() {
        return this.approvalDetails.status || 'Draft';
    }

    get approverName() {
        return this.approvalDetails.approverName || '';
    }

    get isPending() {
        return this.approvalDetails.status === 'Pending';
    }

    get isApproved() {
        return this.approvalDetails.status === 'Approved';
    }

    get canSubmit() {
        return !this.approvalDetails.status || this.approvalDetails.status === 'Draft' || this.approvalDetails.status === 'Rejected';
    }

    get statusClass() {
        const s = this.approvalDetails.status;
        if (s === 'Approved') return 'slds-theme_success';
        if (s === 'Pending') return 'slds-theme_warning';
        if (s === 'Rejected') return 'slds-theme_error';
        return 'slds-theme_shade';
    }

    handleSubmit() {
        this.isLoading = true;
        submitPjpForApproval({ pjpId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Submitted for Approval successfully. Approval request sent to reporting manager.', 'success');
                this.refresh();
            })
            .catch(err => {
                this.showToast('Error', err.body ? err.body.message : err.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleApprove() {
        this.isLoading = true;
        processPjpApproval({ pjpId: this.recordId, action: 'Approve', comments: 'Approved' })
            .then(() => {
                this.showToast('Approved', 'Permanent Journey Plan approved successfully. Employee status updated to Approved.', 'success');
                this.refresh();
            })
            .catch(err => {
                this.showToast('Error', err.body ? err.body.message : err.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReject() {
        this.isLoading = true;
        processPjpApproval({ pjpId: this.recordId, action: 'Reject', comments: 'Rejected' })
            .then(() => {
                this.showToast('Rejected', 'Permanent Journey Plan rejected.', 'info');
                this.refresh();
            })
            .catch(err => {
                this.showToast('Error', err.body ? err.body.message : err.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    refresh() {
        this.loadDetails();
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}