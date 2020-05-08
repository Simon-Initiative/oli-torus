import { ActivityModelSchema, ActivityState, StudentResponse, Hint, Success } from './types';
import { ActivitySlug } from 'data/types';


export type PartResponse = {
  partId: string,
  response: StudentResponse,
};

export interface DeliveryElementProps<T extends ActivityModelSchema> {
  activitySlug: ActivitySlug;
  model: T;
  state: ActivityState;
  onRequestHint: (partIds: string[]) => Promise<Hint>;
  onSave: (partResponses: PartResponse[]) => Promise<Success>;
  onSubmit: (partResponses: PartResponse[]) => void;
  onResetParts: (partIds: string[]) => void;
  onReset: () => void;
}

// An abstract delivery web component, designed to delegate to
// a React component.  This delivery web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes
export abstract class DeliveryElement<T extends ActivityModelSchema> extends HTMLElement {

  mountPoint: HTMLDivElement;
  connected: boolean;
  onRequestHint: (partIds: string[]) => Promise<Hint>;
  onSave: (partResponses: PartResponse[]) => Promise<Success>;
  onSubmit: (partResponses: PartResponse[]) => void;
  onResetParts: (partIds: string[]) => void;
  onReset: () => void;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
    this.connected = false;

    this.onRequestHint = (partIds: string[]) => this.dispatch('onRequestHint', partIds);
    this.onSave = (partResponses: PartResponse[]) => this.dispatch('onSave', partResponses);
    this.onSubmit = (partResponses: PartResponse[]) => this.dispatch('onSubmit', partResponses);
    this.onResetParts = (partIds: string[]) => this.dispatch('onResetParts', partIds);
    this.onReset = () => this.dispatch('onReset');
  }

  dispatch(name: string, payload?: any) : Promise<any> {
    return new Promise((resolve, reject) => {
      const continuation = (result : any, error : any) => {
        if (error !== undefined) {
          reject(error);
          return;
        }
        resolve(result);
      };
      this.dispatchEvent(new CustomEvent(name, this.details(continuation, payload)));
    });
  }

  props() : DeliveryElementProps<T> {

    const model = JSON.parse(this.getAttribute('model') as any);
    const state = JSON.parse(this.getAttribute('state') as any) as ActivityState;
    const activitySlug = this.getAttribute('activitySlug') as any;

    return {
      model,
      activitySlug,
      state,
      onRequestHint: this.onRequestHint,
      onSave: this.onSave,
      onSubmit: this.onSubmit,
      onResetParts: this.onResetParts,
      onReset: this.onReset,
    };
  }

  details(continuation: (result: any, error: any) => void, payload? : any) {
    return {
      bubbles: true,
      detail: {
        activitySlug: this.getAttribute('activitySlug'),
        payload,
        continuation,
      },
    };
  }

  abstract render(mountPoint: HTMLDivElement, props: DeliveryElementProps<T>) : void;

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render(this.mountPoint, this.props());
    this.connected = true;
  }

  attributeChangedCallback(name: any, oldValue: any, newValue: any) {
    if (this.connected) {
      this.render(this.mountPoint, this.props());
    }
  }

  static get observedAttributes() { return ['model', 'state']; }
}
