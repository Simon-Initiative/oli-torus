import { ActivityModelSchema, PostUndoable, Undoable } from './types';
import { ProjectSlug } from 'data/types';
import React, { useCallback, useContext, useMemo } from 'react';
import { Maybe } from 'tsmonad';
import produce from 'immer';

export interface AuthoringElementProps<T extends ActivityModelSchema> {
  model: T;
  onEdit: (model: T) => void;
  onPostUndoable: (undoable: Undoable) => void;
  editMode: boolean;
  projectSlug: ProjectSlug;
}

// An abstract authoring web component, designed to delegate to
// a React authoring component.  This authoring web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes.  It also traps onEdit callbacks from the
// React component and translated these calls into dispatches of the
// 'modelUpdated' CustomEvent.  It is this CustomEvent that is handled by
// Torus to process updates from the authoring web component.
export abstract class AuthoringElement<T extends ActivityModelSchema> extends HTMLElement {
  mountPoint: HTMLDivElement;
  connected: boolean;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
  }

  props(): AuthoringElementProps<T> {
    const getProp = (key: string) => JSON.parse(this.getAttribute(key) as any);
    const model = getProp('model');
    const editMode: boolean = getProp('editMode');
    const projectSlug: ProjectSlug = this.getAttribute('projectSlug') as string;

    const onEdit = (model: any) => {
      this.dispatchEvent(new CustomEvent('modelUpdated', { bubbles: true, detail: { model } }));
    };
    const onPostUndoable = (undoable: Undoable) => {
      this.dispatchEvent(new CustomEvent('postUndoable', { bubbles: true, detail: { undoable } }));
    };

    return {
      onEdit,
      onPostUndoable,
      model,
      editMode,
      projectSlug,
    };
  }

  abstract render(mountPoint: HTMLDivElement, props: AuthoringElementProps<T>): void;

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

  static get observedAttributes() {
    return ['model', 'editMode'];
  }
}

export interface AuthoringElementState {
  projectSlug: string;
  editMode: boolean;
  dispatch: (action: (model: any, post: PostUndoable) => any) => void;
  model: any;
}
const AuthoringElementContext = React.createContext<AuthoringElementState | undefined>(undefined);
export function useAuthoringElementContext() {
  return Maybe.maybe(useContext(AuthoringElementContext)).valueOrThrow(
    new Error('useAuthoringElementContext must be used within an AuthoringElementProvider'),
  );
}
export const AuthoringElementProvider: React.FC<AuthoringElementProps<ActivityModelSchema>> = ({
  projectSlug,
  editMode,
  children,
  model,
  onPostUndoable,
  onEdit,
}) => {
  const dispatch: AuthoringElementState['dispatch'] = (action) =>
    onEdit(produce(model, (draftState) => action(draftState, onPostUndoable)));
  return (
    <AuthoringElementContext.Provider value={{ projectSlug, editMode, dispatch, model }}>
      {children}
    </AuthoringElementContext.Provider>
  );
};
