import { MediaActions } from 'actions/media';
import { combineReducers } from 'redux';
import { ThunkDispatch } from 'redux-thunk';
import { MediaState, initMediaState, media } from 'state/media';
import { ModalActions, ModalState, initModalState, modal } from 'state/modal';
import { OtherAction } from 'state/other';
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
