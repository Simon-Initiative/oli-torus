import { ProjectSlug } from 'data/types';
import { ActivityModelSchema, MediaItemRequest, Undoable } from './types';
import { EventEmitter } from 'events';

export interface AuthoringElementProps<T extends ActivityModelSchema> {
  model: T;
  onEdit: (model: T) => void;
  onPostUndoable: (undoable: Undoable) => void;
  onRequestMedia: (request: MediaItemRequest) => Promise<string | boolean>;
  onCustomEvent?: (eventName: string, payload: any) => Promise<any>;
  editMode: boolean;
  projectSlug: ProjectSlug;
  authoringContext?: any;
  notify?: EventEmitter;
}

/**
  An abstract authoring web component, designed to delegate to
  a React authoring component.  This authoring web component will re-render
  the underlying React component when the 'model' attribute of the
  the web component changes.  It also traps onEdit callbacks from the
  React component and translated these calls into dispatches of the
  'modelUpdated' CustomEvent.  It is this CustomEvent that is handled by
  Torus to process updates from the authoring web component.
  */
export abstract class AuthoringElement<T extends ActivityModelSchema> extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;

  protected _notify: EventEmitter;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
    this.connected = false;
    this._notify = new EventEmitter().setMaxListeners(50);
  }

  props(): AuthoringElementProps<T> {
    const getProp = (key: string) => JSON.parse(this.getAttribute(key) as any);
    const model = this.migrateModelVersion(getProp('model'));
    const editMode: boolean = this.getAttribute('editmode') === 'true';
    const projectSlug: ProjectSlug = this.getAttribute('projectSlug') as string;
    let authoringContext: any = {};
    if (this.getAttribute('authoringcontext')) {
      authoringContext = getProp('authoringcontext');
    }

    const onEdit = (model: T) => {
      this.dispatchEvent(new CustomEvent('modelUpdated', { bubbles: true, detail: { model } }));
    };
    const onPostUndoable = (undoable: Undoable) => {
      this.dispatchEvent(new CustomEvent('postUndoable', { bubbles: true, detail: { undoable } }));
    };
    const onRequestMedia = (request: MediaItemRequest) => {
      return this.dispatch('requestMedia', request);
    };
    const onCustomEvent = (eventName: string, payload: any) => {
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

  migrateModelVersion(model: any): T {
    return model as T;
  }

  details(continuation: (result: any, error: any) => void, payload?: any) {
    return {
      bubbles: true,
      detail: {
        payload,
        continuation,
        props: this.props(),
      },
    };
  }

  dispatch(name: string, payload?: any): Promise<any> {
    return new Promise((resolve, reject) => {
      const continuation = (result: any, error: any) => {
        if (error !== undefined) {
          reject(error);
          return;
        }
        resolve(result);
      };
      this.dispatchEvent(new CustomEvent(name, this.details(continuation, payload)));
    });
  }

  notify(eventName: string, payload: any): void {
    this._notify.emit(eventName, payload);
  }

  abstract render(mountPoint: HTMLDivElement, props: AuthoringElementProps<T>): void;

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render(this.mountPoint, this.props());
    this.connected = true;
  }

  attributeChangedCallback(_name: any, _oldValue: any, _newValue: any) {
    if (this.connected) {
      this.render(this.mountPoint, this.props());
    }
  }

  // Lower case here as opposed to camelCase is required
  static observedAttributes = ['editmode', 'model', 'authoringcontext'];
}
