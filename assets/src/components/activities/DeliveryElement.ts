import { EventEmitter } from 'events';
import { valueOr } from 'utils/common';
import {
  Action,
  ActivityModelSchema,
  ActivityState,
  ClientEvaluation,
  DeliveryMode,
  Hint,
  PartResponse,
  PartState,
  StudentResponse,
  Success,
} from './types';

/**
 * Response to a submitted activity evaluation.
 */
export interface EvaluationResponse extends Success {
  actions: Action[];
}

/**
 * Response to a request for an additional hint.
 * Notice that the hint attribute here is optional.  If a
 * client requests a hint and there are no more, the platform
 * will return an instance of this interface with hasMoreHints set to false
 * and the hint attribute missing.
 */
export interface RequestHintResponse extends Success {
  hint?: Hint;
  hasMoreHints: boolean;
}

/**
 * Response to a request to reset the activity attempt. Resetting
 * an activity attempt simply creates a new activity attempt.
 */
export interface ResetActivityResponse extends Success {
  attemptState: ActivityState;
  model: ActivityModelSchema;
}

/**
 * Response to reset a specific part attempt.
 */
export interface PartActivityResponse extends Success {
  attemptState: PartState;
}

export interface ActivityContext {
  graded: boolean;
  batchScoring: boolean;
  sectionSlug: string;
  projectSlug: string;
  userId: number;
  learningLanguage?: string;
  groupId: string | null;
  surveyId: string | null;
  bibParams: any;
  pageAttemptGuid: string;
  pageState?: any;
  showFeedback: boolean | null;
  resourceId?: number;
  renderPointMarkers: boolean;
  isAnnotationLevel: boolean;
  variables: any;
  pageLinkParams: any;
  allowHints: boolean;
}

/**
 * Delivery web component properties made available via the
 * `render` method.
 */
export interface DeliveryElementProps<T extends ActivityModelSchema> {
  /**
   * The model of the activity, pruned to remove the authoring specific portion.
   */
  model: T;

  /**
   * The state of the activity and part attempts.
   */
  state: ActivityState;

  /**
   * The larger context that this activity operates within.
   */
  context: ActivityContext;

  /**
   * The current delivery mode.
   */
  mode: DeliveryMode;

  /**
   * @ignore
   */
  notify?: EventEmitter;

  /**
   * The HTML div element reference created by the abstract component for use in
   * rendering by the concrete implementation.
   */
  mountPoint?: HTMLElement;

  /**
   * Allows read access to the user state.
   */
  onReadUserState?: (attemptGuid: string, partAttemptGuid: string, payload: any) => Promise<any>;

  /**
   * Allows writing to the user state.
   */
  onWriteUserState?: (attemptGuid: string, partAttemptGuid: string, payload: any) => Promise<any>;

  /**
   * Initiates saving of the student response for all parts.
   */
  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;

  /**
   * Submits all parts of the attempt for evaluation.
   */
  onSubmitActivity: (
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => Promise<EvaluationResponse>;

  /**
   * Resets this activity attempt to create a new attempt.
   */
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>;

  /**
   * Requests a hint for a specific part.
   */
  onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>;

  /**
   * Saves the state of a specific part.
   */
  onSavePart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<Success>;

  /**
   * Submits for evaluation one part.
   */
  onSubmitPart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<EvaluationResponse>;

  /**
   * Resets the attempt for one part.
   */
  onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>;

  /**
   * Submits client-side evaluations.
   */
  onSubmitEvaluations: (
    attemptGuid: string,
    clientEvaluations: ClientEvaluation[],
  ) => Promise<EvaluationResponse>;

  /**
   * @ignore
   */
  onReady?: (attemptGuid: string, responses?: any[]) => Promise<Success>;

  /**
   * @ignore
   */
  onResize?: (attemptGuid: string) => Promise<Success>;
}

/**
 * An abstract delivery web component, designed to delegate rendering
 * via the `render` method.  This delivery web component will re-render
 * when the 'model' attribute of the the web component changes.  It also provides
 * several callback function to allow the concrete implementation to initiate
 * lifecycle events (e.g. request a hint, reset an attempt, etc).
 *
 * While the delegated implementation is a React component in the case of natively
 * implemented activities, this does not need to be the case.  This `DeliveryElement`
 * implementation is tech-stack agnostic.  One can use it to implement the authoring
 * component of a Torus activity in Vanilla JS, React, Vue, Angular, etc.
 *
 * ```typescript
 * // A typical React delegation
 * export class MultipleChoiceDelivery extends DeliveryElement<MCSchema> {
 *   render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MCSchema>) {
 *     const store = configureStore({}, activityDeliverySlice.reducer);
 *     ReactDOM.render(
 *       <Provider store={store}>
 *         <DeliveryElementProvider {...props}>
 *           <MultipleChoiceComponent />
 *         </DeliveryElementProvider>
 *       </Provider>,
 *       mountPoint,
 *     );
 *   }
 *  }
 * ```
 */
export abstract class DeliveryElement<T extends ActivityModelSchema> extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;
  review: boolean;
  onGetData?: (attemptGuid: string, partAttemptGuid: string, payload: any) => Promise<any>;
  onSetData?: (attemptGuid: string, partAttemptGuid: string, payload: any) => Promise<any>;

  protected _notify: EventEmitter;

  onRequestHint: (attemptGuid: string, partAttemptGuid: string) => Promise<RequestHintResponse>;

  onSaveActivity: (attemptGuid: string, partResponses: PartResponse[]) => Promise<Success>;
  onSubmitActivity: (
    attemptGuid: string,
    partResponses: PartResponse[],
  ) => Promise<EvaluationResponse>;
  onResetActivity: (attemptGuid: string) => Promise<ResetActivityResponse>;

  onSavePart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<Success>;
  onSubmitPart: (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => Promise<EvaluationResponse>;
  onResetPart: (attemptGuid: string, partAttemptGuid: string) => Promise<PartActivityResponse>;
  onSubmitEvaluations: (
    attemptGuid: string,
    clientEvaluations: ClientEvaluation[],
  ) => Promise<EvaluationResponse>;
  onReady: (attemptGuid: string, response?: any[]) => Promise<Success>;
  onResize: (attemptGuid: string) => Promise<Success>;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
    this.connected = false;
    this.review = false;

    // need a way to push into the react component w/o rerendering the custom element
    this._notify = new EventEmitter().setMaxListeners(50);

    this.onRequestHint = (attemptGuid: string, partAttemptGuid: string) =>
      this.dispatch('requestHint', attemptGuid, partAttemptGuid);

    this.onGetData = (attemptGuid: string, partAttemptGuid: string, payload: any) =>
      this.dispatch('getUserData', attemptGuid, partAttemptGuid, payload);

    this.onSetData = (attemptGuid: string, partAttemptGuid: string, payload: any) =>
      this.dispatch('setUserData', attemptGuid, partAttemptGuid, payload);

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
    this.onSubmitEvaluations = (attemptGuid: string, clientEvaluations: ClientEvaluation[]) =>
      this.dispatch('submitEvaluations', attemptGuid, undefined, clientEvaluations);

    this.onReady = (attemptGuid: string, response?: any[]) =>
      this.dispatch('activityReady', attemptGuid, undefined, response);
    this.onResize = (attemptGuid: string) => this.dispatch('resizePart', attemptGuid, undefined);
  }

  static get observedAttributes() {
    return ['model', 'state'];
  }

  dispatch(
    name: string,
    attemptGuid: string,
    partAttemptGuid: string | undefined,
    payload?: any,
  ): Promise<any> {
    return new Promise((resolve, reject) => {
      const continuation = (result: any, error: any) => {
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
      this.dispatchEvent(
        new CustomEvent(name, this.details(continuation, attemptGuid, partAttemptGuid, payload)),
      );
    });
  }

  notify(eventName: string, payload: any): void {
    this._notify.emit(eventName, payload);
  }

  props(): DeliveryElementProps<T> {
    // required
    const model = JSON.parse(this.getAttribute('model') as any);
    const context = JSON.parse(this.getAttribute('context') as any) as ActivityContext;
    const state = JSON.parse(this.getAttribute('state') as any) as ActivityState;
    const mode = valueOr(this.getAttribute('mode'), 'delivery') as DeliveryMode;

    this.review = mode === 'review';

    return {
      model,
      state,
      context,
      mode,
      notify: this._notify,
      mountPoint: this.mountPoint,
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
    };
  }

  details(
    continuation: (result: any, error: any) => void,
    attemptGuid: string,
    partAttemptGuid: string | undefined,
    payload?: any,
  ) {
    const props = this.props();

    return {
      bubbles: true,
      detail: {
        payload,
        sectionSlug: props.context.sectionSlug,
        attemptGuid,
        partAttemptGuid,
        continuation,
        props,
      },
    };
  }

  /**
   * Implemented by concrete web component, the `render` method is called
   * once after the web component has been mounted and "connected" to the DOM, and
   * then again every time that either the `state` or `model` attributes have
   * changed on the web component.
   * @param mountPoint a top level div element created by the component that the
   * concrete impl can use to render the rest of the actual UX
   * @param props the current set of delivery component properties
   */
  abstract render(mountPoint: HTMLDivElement, props: DeliveryElementProps<T>): void;

  connectedCallback() {
    // need to skip a cycle to let old elements handle disconnect in LiveView
    setTimeout(() => {
      this.appendChild(this.mountPoint);
      this.render(this.mountPoint, this.props());
      this.connected = true;
    }, 0);
  }

  attributeChangedCallback(_name: any, _oldValue: any, _newValue: any) {
    if (this.connected) {
      this.render(this.mountPoint, this.props());
    }
  }
}
