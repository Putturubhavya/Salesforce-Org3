import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { decodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getBeatGeography from '@salesforce/apex/BeatController.getBeatGeography';

export default class OutletNewModal extends NavigationMixin(LightningElement) {
    @track beatId = '';
    @track geographyId = '';
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
            this.fetchGeography(detectedBeatId);
        }
    }

    handleBeatChange(event) {
        let val = event.detail.value;
        if (Array.isArray(val)) {
            val = val.length > 0 ? val[0] : null;
        }
        this.beatId = val || '';
        if (this.beatId) {
            this.fetchGeography(this.beatId);
        } else {
            this.geographyId = '';
        }
    }

    fetchGeography(beatId) {
        getBeatGeography({ beatId: beatId })
            .then(result => {
                this.geographyId = result || '';
            })
            .catch(error => {
                console.error('Error fetching beat geography:', error);
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
                message: 'Outlet was created successfully.',
                variant: 'success'
            })
        );

        if (this.isSaveAndNew) {
            const currentBeat = this.beatId;
            const currentGeo = this.geographyId;
            const inputFields = this.template.querySelectorAll('lightning-input-field');
            if (inputFields) {
                inputFields.forEach(field => {
                    if (field.fieldName !== 'Beat__c' && field.fieldName !== 'Geography__c') {
                        field.reset();
                    }
                });
            }
            this.beatId = currentBeat;
            this.geographyId = currentGeo;
        } else {
            this.navigateToRecord(recordId);
        }
    }

    handleError(event) {
        this.isSaving = false;
        let errorMessage = 'An error occurred while creating the Outlet.';
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error creating Outlet',
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
                    objectApiName: 'Outlet__c',
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
                objectApiName: 'Outlet__c',
                actionName: 'view'
            }
        });
    }
}