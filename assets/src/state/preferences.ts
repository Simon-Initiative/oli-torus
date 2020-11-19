import { Record } from 'immutable';
import { Maybe } from 'tsmonad';
import { OtherAction } from 'state/other';
import { Dispatch, Action } from 'redux';
import { State } from 'state';
import { valueOr } from 'utils/common';
import {
  Preferences,
  fetchPreferences as fetchPreferencesRequest,
  updatePreferences as updatePreferencesRequest,
} from 'data/persistence/preferences';

//// ACTIONS ////

// update preferences
export type UPDATE_PREFERENCES = 'preferences/UPDATE_PREFERENCES';
export const UPDATE_PREFERENCES: UPDATE_PREFERENCES = 'preferences/UPDATE_PREFERENCES';

export type UpdatePreferencesAction = {
  type: UPDATE_PREFERENCES,
  preferences: Preferences,
};

export const updatePreferences = (preferences: Partial<Preferences>) =>
  async (dispatch: Dispatch<Action>, getState: () => State) => {
    // dispatch any async actions such as AJAX calls, etc...
    const previousState = getState();

    try {
      // optimistically update the state
      dispatch({
        type: UPDATE_PREFERENCES,
        preferences,
      });

      await updatePreferencesRequest(preferences);
    } catch (e) {
      console.error(e);

      // reset to original state before the error
      dispatch({
        type: UPDATE_PREFERENCES,
        preferences: previousState.preferences.preferences,
      });
    }
  };

// load preferences
export type LOAD_PREFERENCES = 'preferences/LOAD_PREFERENCES';
export const LOAD_PREFERENCES: LOAD_PREFERENCES = 'preferences/LOAD_PREFERENCES';

export type LoadPreferencesAction = {
  type: LOAD_PREFERENCES,
  preferences: Preferences,
};

export const loadPreferences = () =>
  async (dispatch: Dispatch<Action>, getState: () => State) => {
    // dispatch any async actions such as AJAX calls, etc...
    const preferences = await fetchPreferencesRequest();

    dispatch({
      type: LOAD_PREFERENCES,
      preferences,
    });
  };

export type PreferencesActions
  = LoadPreferencesAction
  | UpdatePreferencesAction
  | OtherAction;


//// MODEL ////

interface PreferencesStateParams {
  preferences: Maybe<Preferences>;
}

const defaults = (params: Partial<PreferencesStateParams> = {}): PreferencesStateParams => ({
  preferences: valueOr(params.preferences, Maybe.nothing()),
});

export class PreferencesState extends Record(defaults()) implements PreferencesStateParams {
  preferences: Maybe<Preferences>;

  constructor(params?: Partial<PreferencesStateParams>) {
    super(defaults(params));
  }

  with(values: Partial<PreferencesStateParams>) {
    return this.merge(values) as this;
  }
}


//// REDUCER ////

export const initialState: PreferencesState = new PreferencesState();

export const preferences = (
  state: PreferencesState = initialState,
  action: PreferencesActions,
): PreferencesState => {
  switch (action.type) {
    case UPDATE_PREFERENCES:
      return state.with({
        preferences: Maybe.just(action.preferences),
      });
    case LOAD_PREFERENCES:
      return state.with({
        preferences: Maybe.just(action.preferences),
      });
    default:
      return state;
  }
};
