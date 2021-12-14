import produce from 'immer';
import React, { useContext } from 'react';
import { Maybe } from 'tsmonad';
import { EventEmitter } from 'events';
// An abstract authoring web component, designed to delegate to
// a React authoring component.  This authoring web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes.  It also traps onEdit callbacks from the
// React component and translated these calls into dispatches of the
// 'modelUpdated' CustomEvent.  It is this CustomEvent that is handled by
// Torus to process updates from the authoring web component.
export class AuthoringElement extends HTMLElement {
    constructor() {
        super();
        this.mountPoint = document.createElement('div');
        this._notify = new EventEmitter().setMaxListeners(50);
    }
    props() {
        const getProp = (key) => JSON.parse(this.getAttribute(key));
        const model = this.migrateModelVersion(getProp('model'));
        const editMode = this.getAttribute('editmode') === 'true';
        const projectSlug = this.getAttribute('projectSlug');
        let authoringContext = {};
        if (this.getAttribute('authoringcontext')) {
            authoringContext = getProp('authoringcontext');
        }
        const onEdit = (model) => {
            this.dispatchEvent(new CustomEvent('modelUpdated', { bubbles: true, detail: { model } }));
        };
        const onPostUndoable = (undoable) => {
            this.dispatchEvent(new CustomEvent('postUndoable', { bubbles: true, detail: { undoable } }));
        };
        const onRequestMedia = (request) => {
            return this.dispatch('requestMedia', request);
        };
        const onCustomEvent = (eventName, payload) => {
            return this.dispatch('customEvent', { eventName, payload });
        };
        return {
            onEdit,
            onPostUndoable,
            onRequestMedia,
            onCustomEvent,
            model,
            editMode,
            projectSlug,
            authoringContext,
            notify: this._notify,
        };
    }
    migrateModelVersion(model) {
        return model;
    }
    details(continuation, payload) {
        return {
            bubbles: true,
            detail: {
                payload,
                continuation,
                props: this.props(),
            },
        };
    }
    dispatch(name, payload) {
        return new Promise((resolve, reject) => {
            const continuation = (result, error) => {
                if (error !== undefined) {
                    reject(error);
                    return;
                }
                resolve(result);
            };
            this.dispatchEvent(new CustomEvent(name, this.details(continuation, payload)));
        });
    }
    notify(eventName, payload) {
        this._notify.emit(eventName, payload);
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
// Lower case here as opposed to camelCase is required
AuthoringElement.observedAttributes = ['editmode', 'model', 'authoringcontext'];
const AuthoringElementContext = React.createContext(undefined);
export function useAuthoringElementContext() {
    return Maybe.maybe(useContext(AuthoringElementContext)).valueOrThrow(new Error('useAuthoringElementContext must be used within an AuthoringElementProvider'));
}
export const AuthoringElementProvider = ({ projectSlug, editMode, children, model, onPostUndoable, onRequestMedia, onEdit, }) => {
    const dispatch = (action) => {
        const newModel = produce(model, (draftState) => action(draftState, onPostUndoable));
        onEdit(newModel);
        return newModel;
    };
    return (<AuthoringElementContext.Provider value={{ projectSlug, editMode, dispatch, model, onRequestMedia }}>
      {children}
    </AuthoringElementContext.Provider>);
};
//# sourceMappingURL=AuthoringElement.jsx.map