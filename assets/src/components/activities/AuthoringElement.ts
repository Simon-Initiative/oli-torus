import { EventEmitter } from 'events';
import { ProjectSlug } from 'data/types';
import { ActivityModelSchema, MediaItemRequest, Undoable } from './types';

// When an authoring element is used inside a section as part of the instructor preview, it gets some extra params sent in.
export interface SectionAuthoringProps {
  activityId?: number;
  sectionSlug?: string;
}

export interface AuthoringElementProps<T extends ActivityModelSchema> {
  model: T;
  onEdit: (model: T) => void;
  onPostUndoable: (undoable: Undoable) => void;
  onRequestMedia: (request: MediaItemRequest) => Promise<string | boolean>;
  onCustomEvent?: (eventName: string, payload: any) => Promise<any>;
  editMode: boolean;
  mode?: 'authoring' | 'instructor_preview';
  projectSlug: ProjectSlug;
  authoringContext?: any;
  notify?: EventEmitter;
  activityId?: number;
  student_responses?: any;
}

/**
 * An abstract authoring web component, designed to delegate rendering
 * via the `render` method.  This authoring web component will re-render
 * when the 'model' attribute of the the web component changes.  It also traps onEdit
 * callbacks from the concrete implementation and translates these calls into dispatches of the
 * 'modelUpdated' CustomEvent.  It is this CustomEvent that is handled by
 * Torus to process updates from the authoring web component.
 *
 * While the delegated implementation is a React component in the case of natively
 * implemented activities, this does not need to be the case.  This `AuthoringElement`
 * implementation is tech-stack agnostic.  One can use it to implement the authoring
 * component of a Torus activity in Vanilla JS, React, Vue, Angular, etc.
 *
 * ```typescript
 * // A typical React delegation
 * export class MultipleChoiceAuthoring extends AuthoringElement<MCSchema> {
 *
 *   render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MCSchema>) {
 *     ReactDOM.render(
 *       <Provider store={store}>
 *         <AuthoringElementProvider {...props}>
 *           <MultipleChoice />
 *         </AuthoringElementProvider>
 *       </Provider>,
 *       mountPoint,
 *     );
 *   }
 * }
 * ```
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

  props(): AuthoringElementProps<T> & SectionAuthoringProps {
    const getProp = (key: string) => JSON.parse(this.getAttribute(key) as any);
    const model = this.migrateModelVersion(getProp('model'));
    const editMode: boolean = this.getAttribute('editmode') === 'true';
    const mode: 'authoring' | 'instructor_preview' =
      (this.getAttribute('mode') as 'authoring' | 'instructor_preview') || 'authoring';
    const projectSlug: ProjectSlug = this.getAttribute('projectSlug') as string;

    const sectionSlug = this.getAttribute('section_slug') || '';
    const htmlActivityId = this.getAttribute('activity_id') || 'activityid_-1';
    const [, activityId] = htmlActivityId.split('_');

    let authoringContext: any = {};
    if (this.getAttribute('authoringcontext')) {
      authoringContext = getProp('authoringcontext');
    }

    let student_responses: any;
    if (this.getAttribute('student_responses')) {
      student_responses = getProp('student_responses');
    }

    const onEdit = (model: T) => {
      this.dispatchEvent(
        new CustomEvent('modelUpdated', { composed: true, bubbles: true, detail: { model } }),
      );
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
      activityId: parseInt(activityId, 10),
      sectionSlug,
      onEdit,
      onPostUndoable,
      onRequestMedia,
      onCustomEvent,
      model,
      editMode,
      mode,
      projectSlug,
      authoringContext,
      notify: this._notify,
      student_responses,
    };
  }

  /**
   * Allows for an activity to perform an inline, just in time, model migration. As an activity's
   * implementation changes over time, it may become necessary to make structural changes to the
   * schema of the activity's model. The activity will need to support the original versions of this
   * model, however, as there will likely have been many instances of this original model already
   * created and stored in the Torus database.
   *
   * The `migrateModelVersion` function will be called by the component just before each call to `render`.
   *
   * @param model the state of the model of the activity, as deliveredy by Torus to this activity
   * @returns a possibly migrated (i.e. upgraded) activity model, or the model as-is if no
   * migration is needed
   */
  migrateModelVersion(model: any): T {
    return model as T;
  }

  details(continuation: (result: any, error: any) => void, payload?: any) {
    return {
      bubbles: true,
      composed: true,
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

  /**
   * Implemented by concrete web component, the `render` method is called
   * once after the web component has been mounted and "connected" to the DOM, and
   * then again every time that either the `editMode` or `model` attributes have
   * changed on the web component.
   * @param mountPoint a top level div element created by the component that the
   * concrete impl can use to render the rest of the actual UX
   * @param props the current set of authoring component properties
   */
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
  static observedAttributes = [
    'editmode',
    'model',
    'authoringcontext',
    'mode',
    'student_responses',
  ];
}
