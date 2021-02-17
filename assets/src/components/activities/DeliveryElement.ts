import { ActivityModelSchema, ActivityState, PartResponse,
  StudentResponse, Hint, Success, PartState } from './types';
import { valueOr } from 'utils/common';


export interface EvaluatedPart {
  type: 'EvaluatedPart';
  attempt_guid: string;
  out_of: number;
  score: number;
  feedback: any;
  error?: string;
}

export interface EvaluationResponse extends Success {
  evaluations: EvaluatedPart[];
}

// Notice that the hint attribute here is optional.  If a
// client requests a hint and there are no more, the platform
// will return an instance of this interface with hasMoreHints set to false
// and the hint attribute missing.
export interface RequestHintResponse extends Success {
  hint?: Hint;
  hasMoreHints: boolean;
}

export interface ResetActivityResponse extends Success {
  attemptState: ActivityState;
  model: ActivityModelSchema;
}


export interface PartActivityResponse extends Success {
  attemptState: PartState;
}

export interface DeliveryElementProps<T extends ActivityModelSchema> {
  graded: boolean;
  model: T;
  state: ActivityState;
  preview: boolean;
  progress_state: string;

  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSubmitActivity: (attemptGuid: string,
    partResponses: PartResponse[]) => Promise<EvaluationResponse>;
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>;

  onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>;
  onSavePart: (attemptGuid: string, partAttemptGuid: string,
    response: StudentResponse) => Promise<Success>;
  onSubmitPart: (attemptGuid: string, partAttemptGuid: string,
    response: StudentResponse) => Promise<EvaluationResponse>;
  onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>;
}

// An abstract delivery web component, designed to delegate to
// a React component.  This delivery web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes
export abstract class DeliveryElement<T extends ActivityModelSchema> extends HTMLElement {

  mountPoint: HTMLDivElement;
  connected: boolean;
  progress_state: string;

  onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>;

  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSubmitActivity: (attemptGuid: string,
    partResponses: PartResponse[]) => Promise<EvaluationResponse>;
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>;

  onSavePart: (attemptGuid: string, partAttemptGuid: string,
    response: StudentResponse) => Promise<Success>;
  onSubmitPart: (attemptGuid: string, partAttemptGuid: string,
    response: StudentResponse) => Promise<EvaluationResponse>;
  onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
    this.connected = false;

    this.onRequestHint = (attemptGuid: string, partAttemptGuid: string) => this.dispatch('requestHint', attemptGuid, partAttemptGuid);

    this.onSaveActivity = (attemptGuid: string, partResponses: PartResponse[]) =>
      this.dispatch('saveActivity', attemptGuid, undefined, partResponses);
    this.onSubmitActivity = (attemptGuid: string, partResponses: PartResponse[]) =>
      this.dispatch('submitActivity', attemptGuid, undefined, partResponses);
    this.onResetActivity = (attemptGuid: string) =>
      this.dispatch('resetActivity', attemptGuid, undefined);

    this.onSavePart = (attemptGuid: string, partAttemptGuid: string, response: StudentResponse) =>
      this.dispatch('savePart', attemptGuid, partAttemptGuid, response);
    this.onSubmitPart = (attemptGuid: string, partAttemptGuid: string, response: StudentResponse) =>
      this.dispatch('submitPart', attemptGuid, partAttemptGuid, response);
    this.onResetPart = (attemptGuid: string, partAttemptGuid: string) =>
      this.dispatch('resetPart', attemptGuid, partAttemptGuid);
  }

  dispatch(name: string, attemptGuid: string,
    partAttemptGuid: string | undefined, payload?: any) : Promise<any> {
    return new Promise((resolve, reject) => {
      const continuation = (result : any, error : any) => {
        if (error !== undefined) {
          reject(error);
          return;
        }
        resolve(result);
      };
      if(this.progress_state === 'in_review'){
        console.log("in review mode")
        continuation(null, "in review mode");
        return;
      }
      this.dispatchEvent(new CustomEvent(
        name, this.details(continuation, attemptGuid, partAttemptGuid, payload)));
    });
  }

  props() : DeliveryElementProps<T> {

    const model = JSON.parse(this.getAttribute('model') as any);
    const graded = JSON.parse(this.getAttribute('graded') as any);
    const state = JSON.parse(this.getAttribute('state') as any) as ActivityState;
    const preview = valueOr(JSON.parse(this.getAttribute('preview') as any), false);
    const progress_state = this.getAttribute('progress_state') as any;

    this.progress_state = progress_state;

    return {
      graded,
      model,
      state,
      preview,
      progress_state,
      onRequestHint: this.onRequestHint,
      onSavePart: this.onSavePart,
      onSubmitPart: this.onSubmitPart,
      onResetPart: this.onResetPart,
      onSaveActivity: this.onSaveActivity,
      onSubmitActivity: this.onSubmitActivity,
      onResetActivity: this.onResetActivity,
    };
  }

  details(continuation: (result: any, error: any) => void,
    attemptGuid: string, partAttemptGuid: string | undefined, payload? : any) {
    return {
      bubbles: true,
      detail: {
        payload,
        attemptGuid,
        partAttemptGuid,
        continuation,
        props: this.props(),
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
