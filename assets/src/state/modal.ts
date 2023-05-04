import { Maybe } from 'tsmonad';
import { modalActions } from '../actions/modal';
import { OtherAction } from './other';

export type ModalActions = modalActions.dismissAction | modalActions.displayAction | OtherAction;

export type ModalState = Maybe<any>;

const defaultState = Maybe.nothing();

export function initModalState(json: any) {
  return Maybe.nothing();
}

export function modal(state: ModalState = defaultState, action: ModalActions): ModalState {
  switch (action.type) {
    case modalActions.DISMISS_MODAL:
      return Maybe.nothing();
    case modalActions.DISPLAY_MODAL:
      return Maybe.just(action.component);
    default:
      return state;
  }
}
