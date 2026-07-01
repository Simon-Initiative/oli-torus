import { EventEmitter } from 'events';
import { ActivityModelSchema, PreviewContext } from './types';

export interface PreviewElementProps<
  T extends ActivityModelSchema,
  C extends PreviewContext = PreviewContext,
> {
  model: T;
  previewContext: C;
  mode: 'preview';
  notify?: EventEmitter;
}

/**
 * A read-only preview web component for instructor-facing inspection surfaces.
 * Like the delivery/authoring base elements, this wrapper is rendering-library
 * agnostic and simply delegates actual UI work through `render`.
 */
export abstract class PreviewElement<
  T extends ActivityModelSchema,
  C extends PreviewContext = PreviewContext,
> extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;

  protected _notify: EventEmitter;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
    this.connected = false;
    this._notify = new EventEmitter().setMaxListeners(50);
  }

  props(): PreviewElementProps<T, C> {
    const getProp = (key: string) => JSON.parse(this.getAttribute(key) as string);
    const model = this.migrateModelVersion(getProp('model'));
    const previewContext = getProp('previewcontext') as C;
    const mode = (this.getAttribute('mode') as 'preview') || 'preview';

    return {
      model,
      previewContext,
      mode,
      notify: this._notify,
    };
  }

  migrateModelVersion(model: any): T {
    return model as T;
  }

  abstract render(mountPoint: HTMLDivElement, props: PreviewElementProps<T, C>): void;

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render(this.mountPoint, this.props());
    this.connected = true;
  }

  attributeChangedCallback(_name: string, _oldValue: string, _newValue: string) {
    if (this.connected) {
      this.render(this.mountPoint, this.props());
    }
  }

  static observedAttributes = ['model', 'previewcontext', 'mode'];
}
