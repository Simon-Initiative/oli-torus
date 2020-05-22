import { ThunkDispatch } from 'redux-thunk';

import { combineReducers } from 'redux';
import { OtherAction } from 'state/other';
import { MediaActions } from 'actions/media';
import { MediaState, media, initMediaState } from 'state/media';
import { ModalActions, ModalState, modal, initModalState } from 'state/modal';

export interface State {
  media: MediaState;
  modal: ModalState;
}

type AllActions = ModalActions | MediaActions | OtherAction;

export type Dispatch = ThunkDispatch<State, void, AllActions>;

export default combineReducers<State>({
  media,
  modal,
});

export function initState(json: any = {}) {
  return {
    media: initMediaState(json),
    modal: initModalState(json),
  };
}
