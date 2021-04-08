import { ThunkDispatch } from 'redux-thunk';

import { combineReducers } from 'redux';
import { OtherAction } from 'state/other';
import { MediaActions } from 'actions/media';
import { MediaState, media, initMediaState } from 'state/media';
import { ModalActions, ModalState, modal, initModalState } from 'state/modal';
import { PreferencesActions, PreferencesState, preferences } from 'state/preferences';

export interface State {
  media: MediaState;
  modal: ModalState;
  preferences: PreferencesState;
}

type AllActions = ModalActions | MediaActions | PreferencesActions | OtherAction;

export type Dispatch = ThunkDispatch<State, void, AllActions>;

export default combineReducers<State>({
  media,
  modal,
  preferences,
});

export function initState(json: any = {}) {
  return {
    media: initMediaState(json),
    modal: initModalState(json),
    preferences: new PreferencesState(json),
  };
}

