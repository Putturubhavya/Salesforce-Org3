import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { decodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getBeatEmployee from '@salesforce/apex/BeatController.getBeatEmployee';

export default class PjpNewModal extends NavigationMixin(LightningElement) {
    @track beatId = '';
    @track employeeId = '';
    @track isSaving = false;
    isSaveAndNew = false;

    @wire(CurrentPageReference)
    setCurrentPageRef(pageRef) {
        if (!pageRef || !pageRef.state) return;
        const state = pageRef.state;
        let detectedBeatId = null;

        // 1. Check defaultFieldValues
        if (state.defaultFieldValues) {
            try {
                const defaults = decodeDefaultFieldValues(state.defaultFieldValues);
                if (defaults && defaults.Beat__c) {
                    detectedBeatId = defaults.Beat__c;
                }
            } catch (e) {
                console.warn('Could not decode defaultFieldValues', e);
            }
        }

        // 2. Check inContextOfRef (standard related list navigation)
        if (!detectedBeatId && state.inContextOfRef) {
            try {
                let contextStr = state.inContextOfRef;
                if (contextStr.startsWith('1.')) {
                    contextStr = contextStr.substring(2);
                }
                const contextJson = JSON.parse(window.atob(contextStr));
                if (contextJson && contextJson.attributes && contextJson.attributes.recordId) {
                    const recId = contextJson.attributes.recordId;
                    if (contextJson.attributes.objectApiName === 'Beat__c' || (recId && recId.startsWith('a02'))) {
                        detectedBeatId = recId;
                    }
                }
            } catch (e) {
                console.warn('Could not parse inContextOfRef', e);
            }
        }

        // 3. Direct URL parameters
        if (!detectedBeatId && state.c__beatId) {
            detectedBeatId = state.c__beatId;
        }

        if (detectedBeatId) {
            this.beatId = detectedBeatId;
            this.fetchEmployee(detectedBeatId);
        }
    }

    handleBeatChange(event) {
        let val = event.detail.value;
        if (Array.isArray(val)) {
            val = val.length > 0 ? val[0] : null;
        }
        this.beatId = val || '';
        if (this.beatId) {
            this.fetchEmployee(this.beatId);
        } else {
            this.employeeId = '';
        }
    }

    fetchEmployee(beatId) {
        getBeatEmployee({ beatId: beatId })
            .then(result => {
                this.employeeId = result || '';
            })
            .catch(error => {
                console.error('Error fetching beat employee:', error);
            });
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
        if (this.beatId) {
            fields.Beat__c = this.beatId;
        }
        if (this.employeeId) {
            fields.Employee__c = this.employeeId;
        }
    }

    handleSuccess(event) {
        this.isSaving = false;
        const recordId = event.detail.id;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Permanent Journey Plan was created successfully.',
                variant: 'success'
            })
        );

        if (this.isSaveAndNew) {
            const currentBeat = this.beatId;
            const currentEmp = this.employeeId;
            const inputFields = this.template.querySelectorAll('lightning-input-field');
            if (inputFields) {
                inputFields.forEach(field => {
                    if (field.fieldName !== 'Beat__c' && field.fieldName !== 'Employee__c') {
                        field.reset();
                    }
                });
            }
            this.beatId = currentBeat;
            this.employeeId = currentEmp;
        } else {
            this.navigateToRecord(recordId);
        }
    }

    handleError(event) {
        this.isSaving = false;
        let errorMessage = 'An error occurred while creating the Permanent Journey Plan.';
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error creating Permanent Journey Plan',
                message: errorMessage,
                variant: 'error'
            })
        );
    }

    closeModal() {
        this.dispatchEvent(new CustomEvent('close'));
        if (this.beatId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.beatId,
                    objectApiName: 'Beat__c',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Permanent_Journey_Plan__c',
                    actionName: 'home'
                }
            });
        }
    }

    navigateToRecord(recordId) {
        this.dispatchEvent(new CustomEvent('close'));
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Permanent_Journey_Plan__c',
                actionName: 'view'
            }
        });
    }
}