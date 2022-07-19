import produce from 'immer';
import React, { useContext } from 'react';
import { Maybe } from 'tsmonad';
import { ActivityModelSchema, MediaItemRequest, PostUndoable } from './types';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { AuthoringElementProps } from './AuthoringElement';

export interface AuthoringElementState<T> {
  projectSlug: string;
  editMode: boolean;
  onRequestMedia: (request: MediaItemRequest) => Promise<string | boolean>;
  dispatch: (action: (model: T, post: PostUndoable) => any) => T;
  model: T;
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
  onPostUndoable,
  onRequestMedia,
  onEdit,
}) => {
  const dispatch: AuthoringElementState<any>['dispatch'] = (action) => {
    const newModel = produce(model, (draftState) => action(draftState, onPostUndoable));
    onEdit(newModel);
    return newModel;
  };
  return (
    <AuthoringElementContext.Provider
      value={{ projectSlug, editMode, dispatch, model, onRequestMedia }}
    >
      {children}
      <ModalDisplay />
    </AuthoringElementContext.Provider>
  );
};
