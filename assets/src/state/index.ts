import { ThunkDispatch } from 'redux-thunk';

import { combineReducers } from 'redux';
import { counter, CounterState, CounterActions } from 'state/counter';
import { OtherAction } from 'state/other';

export interface State {
  counter: CounterState;
}

type AllActions = CounterActions
  | OtherAction;

export type Dispatch = ThunkDispatch<State, void, AllActions>;

export default combineReducers<State>({
  counter,
});

export function initState(json: any = {}) {
  return {
    counter: new CounterState(json.counter),
  };
}
