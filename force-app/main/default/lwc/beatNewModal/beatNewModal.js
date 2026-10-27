import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmployeeGeography from '@salesforce/apex/BeatController.getEmployeeGeography';

export default class BeatNewModal extends NavigationMixin(LightningElement) {
    @track geographyId = '';
    @track isSaving = false;
    isSaveAndNew = false;

    handleEmployeeChange(event) {
        let employeeId = event.detail.value;
        if (Array.isArray(employeeId)) {
            employeeId = employeeId.length > 0 ? employeeId[0] : null;
        }

        if (employeeId) {
            getEmployeeGeography({ employeeId: employeeId })
                .then(result => {
                    this.geographyId = result || '';
                })
                .catch(error => {
                    console.error('Error fetching employee geography:', error);
                });
        } else {
            this.geographyId = '';
        }
    }

    handleCancel() {
        this.closeModal();
    }

    handleSave() {
        this.isSaveAndNew = false;
        this.submitForm();
    }

    handleSaveAndNew() {
        this.isSaveAndNew = true;
        this.submitForm();
    }

    submitForm() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            this.isSaving = true;
            form.submit();
        }
    }

    handleSubmit(event) {
        const fields = event.detail.fields;
        if (this.geographyId) {
            fields.Geography__c = this.geographyId;
        }
    }

    handleSuccess(event) {
        this.isSaving = false;
        const recordId = event.detail.id;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Beat was created successfully.',
                variant: 'success'
            })
        );

        if (this.isSaveAndNew) {
            this.geographyId = '';
            const inputFields = this.template.querySelectorAll('lightning-input-field');
            if (inputFields) {
                inputFields.forEach(field => {
                    field.reset();
                });
            }
        } else {
            this.navigateToRecord(recordId);
        }
    }

    handleError(event) {
        this.isSaving = false;
        let errorMessage = 'An error occurred while creating the Beat.';
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error creating Beat',
                message: errorMessage,
                variant: 'error'
            })
        );
    }

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Beat__c',
                actionName: 'home'
            }
        });
    }

    navigateToRecord(recordId) {
        this.dispatchEvent(new CustomEvent('close'));
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Beat__c',
                actionName: 'view'
            }
        });
    }
}