import { ActivityModelSchema, ActivityState, StudentResponse, Hint, Success } from './types';

export type PartResponse = {
  attemptGuid: string,
  response: StudentResponse,
};

export interface DeliveryElementProps<T extends ActivityModelSchema> {
  model: T;
  state: ActivityState;

  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSubmitActivity: (attemptGuid: string, partResponses: PartResponse[]) => void;
  onResetActivity: (attemptGuid: string) => void;

  onRequestHint: (attemptGuid: string) => Promise<Hint>;
  onSavePart: (attemptGuid: string, response: StudentResponse) => Promise<Success>;
  onSubmitPart: (attemptGuid: string, response: StudentResponse) => void;
  onResetPart: (attemptGuid: string) => void;
}

// An abstract delivery web component, designed to delegate to
// a React component.  This delivery web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes
export abstract class DeliveryElement<T extends ActivityModelSchema> extends HTMLElement {

  mountPoint: HTMLDivElement;
  connected: boolean;

  onRequestHint: (attemptGuid: string) => Promise<Hint>;

  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSubmitActivity: (attemptGuid: string, partResponses: PartResponse[]) => void;
  onResetActivity: (attemptGuid: string) => void;

  onSavePart: (attemptGuid: string, response: StudentResponse) => Promise<Success>;
  onSubmitPart: (attemptGuid: string, response: StudentResponse) => void;
  onResetPart: (attemptGuid: string) => void;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
    this.connected = false;

    this.onRequestHint = (attemptGuid: string) => this.dispatch('requestHint', attemptGuid);

    this.onSaveActivity = (attemptGuid: string, partResponses: PartResponse[]) =>
      this.dispatch('saveActivity', attemptGuid, partResponses);
    this.onSubmitActivity = (attemptGuid: string, partResponses: PartResponse[]) =>
      this.dispatch('submitActivity', attemptGuid, partResponses);
    this.onResetActivity = (attemptGuid: string) => this.dispatch('resetActivity', attemptGuid);

    this.onSavePart = (attemptGuid: string, response: StudentResponse) =>
      this.dispatch('savePart', attemptGuid, response);
    this.onSubmitPart = (attemptGuid: string, response: StudentResponse) =>
      this.dispatch('submitPart', attemptGuid, response);
    this.onResetPart = (attemptGuid: string) => this.dispatch('resetPart', attemptGuid);
  }

  dispatch(name: string, attemptGuid: string, payload?: any) : Promise<any> {
    return new Promise((resolve, reject) => {
      const continuation = (result : any, error : any) => {
        if (error !== undefined) {
          reject(error);
          return;
        }
        resolve(result);
      };
      this.dispatchEvent(new CustomEvent(name, this.details(continuation, attemptGuid, payload)));
    });
  }

  props() : DeliveryElementProps<T> {

    const model = JSON.parse(this.getAttribute('model') as any);
    const state = JSON.parse(this.getAttribute('state') as any) as ActivityState;

    return {
      model,
      state,
      onRequestHint: this.onRequestHint,
      onSavePart: this.onSavePart,
      onSubmitPart: this.onSubmitPart,
      onResetPart: this.onResetPart,
      onSaveActivity: this.onSaveActivity,
      onSubmitActivity: this.onSubmitActivity,
      onResetActivity: this.onResetActivity,
    };
  }

  details(continuation: (result: any, error: any) => void, attemptGuid: string, payload? : any) {
    return {
      bubbles: true,
      detail: {
        payload,
        attemptGuid,
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
