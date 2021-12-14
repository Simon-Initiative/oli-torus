import { EventEmitter } from 'events';
import { Maybe } from 'tsmonad';
import { valueOr } from 'utils/common';
import React, { useContext } from 'react';
import { defaultWriterContext } from 'data/content/writers/context';
// An abstract delivery web component, designed to delegate to
// a React component.  This delivery web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes
export class DeliveryElement extends HTMLElement {
    constructor() {
        super();
        this.mountPoint = document.createElement('div');
        this.connected = false;
        // need a way to push into the react component w/o rerendering the custom element
        this._notify = new EventEmitter().setMaxListeners(50);
        this.onRequestHint = (attemptGuid, partAttemptGuid) => this.dispatch('requestHint', attemptGuid, partAttemptGuid);
        this.onGetData = (attemptGuid, partAttemptGuid, payload) => this.dispatch('getUserData', attemptGuid, partAttemptGuid, payload);
        this.onSetData = (attemptGuid, partAttemptGuid, payload) => this.dispatch('setUserData', attemptGuid, partAttemptGuid, payload);
        this.onSaveActivity = (attemptGuid, partResponses) => this.dispatch('saveActivity', attemptGuid, undefined, partResponses);
        this.onSubmitActivity = (attemptGuid, partResponses) => this.dispatch('submitActivity', attemptGuid, undefined, partResponses);
        this.onResetActivity = (attemptGuid) => this.dispatch('resetActivity', attemptGuid, undefined);
        this.onSavePart = (attemptGuid, partAttemptGuid, response) => this.dispatch('savePart', attemptGuid, partAttemptGuid, response);
        this.onSubmitPart = (attemptGuid, partAttemptGuid, response) => this.dispatch('submitPart', attemptGuid, partAttemptGuid, response);
        this.onResetPart = (attemptGuid, partAttemptGuid) => this.dispatch('resetPart', attemptGuid, partAttemptGuid);
        this.onSubmitEvaluations = (attemptGuid, clientEvaluations) => this.dispatch('submitEvaluations', attemptGuid, undefined, clientEvaluations);
        this.onReady = (attemptGuid) => this.dispatch('activityReady', attemptGuid, undefined);
        this.onResize = (attemptGuid) => this.dispatch('resizePart', attemptGuid, undefined);
    }
    static get observedAttributes() {
        return ['model', 'state'];
    }
    dispatch(name, attemptGuid, partAttemptGuid, payload) {
        return new Promise((resolve, reject) => {
            const continuation = (result, error) => {
                if (error !== undefined) {
                    reject(error);
                    return;
                }
                resolve(result);
            };
            if (this.review) {
                continuation(null, 'in review mode');
                return;
            }
            this.dispatchEvent(new CustomEvent(name, this.details(continuation, attemptGuid, partAttemptGuid, payload)));
        });
    }
    notify(eventName, payload) {
        this._notify.emit(eventName, payload);
    }
    props() {
        const model = JSON.parse(this.getAttribute('model'));
        const graded = JSON.parse(this.getAttribute('graded'));
        const state = JSON.parse(this.getAttribute('state'));
        const mode = valueOr(this.getAttribute('mode'), 'delivery');
        const sectionSlug = valueOr(this.getAttribute('section_slug'), undefined);
        const userId = this.getAttribute('user_id');
        this.review = mode === 'review';
        return {
            graded,
            model,
            state,
            mode,
            sectionSlug,
            onWriteUserState: this.onSetData,
            onReadUserState: this.onGetData,
            onRequestHint: this.onRequestHint,
            onSavePart: this.onSavePart,
            onSubmitPart: this.onSubmitPart,
            onResetPart: this.onResetPart,
            onSaveActivity: this.onSaveActivity,
            onSubmitActivity: this.onSubmitActivity,
            onResetActivity: this.onResetActivity,
            onSubmitEvaluations: this.onSubmitEvaluations,
            onReady: this.onReady,
            onResize: this.onResize,
            userId,
            notify: this._notify,
            mountPoint: this.mountPoint,
        };
    }
    details(continuation, attemptGuid, partAttemptGuid, payload) {
        return {
            bubbles: true,
            detail: {
                payload,
                sectionSlug: this.props().sectionSlug,
                attemptGuid,
                partAttemptGuid,
                continuation,
                props: this.props(),
            },
        };
    }
    connectedCallback() {
        this.appendChild(this.mountPoint);
        this.render(this.mountPoint, this.props());
        this.connected = true;
    }
    attributeChangedCallback(_name, _oldValue, _newValue) {
        if (this.connected) {
            this.render(this.mountPoint, this.props());
        }
    }
}
const DeliveryElementContext = React.createContext(undefined);
export function useDeliveryElementContext() {
    return Maybe.maybe(useContext(DeliveryElementContext)).valueOrThrow(new Error('useDeliveryElementContext must be used within an DeliveryElementProvider'));
}
export const DeliveryElementProvider = (props) => {
    const writerContext = defaultWriterContext({ sectionSlug: props.sectionSlug });
    return (<DeliveryElementContext.Provider value={Object.assign(Object.assign({}, props), { writerContext })}>
      {props.children}
    </DeliveryElementContext.Provider>);
};
//# sourceMappingURL=DeliveryElement.jsx.map