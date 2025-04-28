import React, { useContext, useRef } from 'react';
import produce from 'immer';
import { Maybe } from 'tsmonad';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { AuthoringElementProps } from './AuthoringElement';
import { ActivityModelSchema, MediaItemRequest, PostUndoable } from './types';

export interface AuthoringElementState<T> {
  projectSlug: string;
  editMode: boolean;
  authoringContext: any;
  onRequestMedia: (request: MediaItemRequest) => Promise<string | boolean>;
  dispatch: (action: (model: T, post: PostUndoable) => any) => T;
  model: T;
  activityId?: number;
}
const AuthoringElementContext = React.createContext<AuthoringElementState<any> | undefined>(
  undefined,
);
export function useAuthoringElementContext<T>() {
  return Maybe.maybe(
    useContext<AuthoringElementState<T> | undefined>(AuthoringElementContext),
  ).valueOrThrow(
    new Error('useAuthoringElementContext must be used within an AuthoringElementProvider'),
  );
}
export const AuthoringElementProvider: React.FC<AuthoringElementProps<ActivityModelSchema>> = ({
  projectSlug,
  editMode,
  children,
  model,
  authoringContext,
  activityId,
  onPostUndoable,
  onRequestMedia,
  onEdit,
}) => {
  const modelRef = useRef(model);
  modelRef.current = model;

  const dispatch: AuthoringElementState<any>['dispatch'] = (action) => {
    /*
    Got into an interesting situation where this dispatch function was closed over an outdated version of `model`
    causing previous updates to be undone.

    ie: these were not the same value when called:
                  model.authoring.parts[0].responses[0].feedback
      modelRef.current?.authoring.parts[0].responses[0].feedback
    */
    const newModel = produce(modelRef.current, (draftState) => action(draftState, onPostUndoable));
    onEdit(newModel);
    return newModel;
  };
  return (
    <AuthoringElementContext.Provider
      value={{
        projectSlug,
        editMode,
        dispatch,
        model,
        onRequestMedia,
        authoringContext,
        activityId,
      }}
    >
      <ErrorBoundary>{children}</ErrorBoundary>
    </AuthoringElementContext.Provider>
  );
};
