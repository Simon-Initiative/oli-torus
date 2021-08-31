import { modalActions } from '../actions/modal';
import * as Immutable from 'immutable';
import { OtherAction } from './other';

export type ModalActions = modalActions.dismissAction | modalActions.displayAction | OtherAction;

export type ModalState = Immutable.Stack<any>;

const defaultState = Immutable.Stack<any>();

export function initModalState(json: any) {
  return Immutable.Stack<any>();
}

export function modal(state: ModalState = defaultState, action: ModalActions): ModalState {
  switch (action.type) {
    case modalActions.DISMISS_MODAL:
      return state.pop();
    case modalActions.DISPLAY_MODAL:
      return state.push(action.component);
    default:
      return state;
  }
}
