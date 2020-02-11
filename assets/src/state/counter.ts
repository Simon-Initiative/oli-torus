import { Record, List } from 'immutable';
import { Maybe } from 'tsmonad';
import { OtherAction } from 'state/other';
import { Dispatch, Action } from 'redux';
import { State } from 'state';
import { valueOr } from 'utils/common';

//// ACTIONS ////

// update count
export type UPDATE_COUNT = 'count/UPDATE_COUNT';
export const UPDATE_COUNT: UPDATE_COUNT = 'count/UPDATE_COUNT';

export type UpdateCountAction = {
  type: UPDATE_COUNT,
  count: number,
};

export const updateCount = (count: number) =>
  async (dispatch: Dispatch<Action>, getState: () => State) => {
    // dispatch any async actions such as AJAX calls, etc...

    dispatch({
      type: UPDATE_COUNT,
      count,
    });
  };

// clear count
export type CLEAR_COUNT = 'count/CLEAR_COUNT';
export const CLEAR_COUNT: CLEAR_COUNT = 'count/CLEAR_COUNT';

export type ClearCountAction = {
  type: CLEAR_COUNT,
};

export const clearCount = (): ClearCountAction => ({
  type: CLEAR_COUNT,
});

export type CounterActions
  = ClearCountAction
  | UpdateCountAction
  | ClearCountAction
  | OtherAction;


//// MODEL ////

interface CounterStateParams {
  count: number;
  animals: Maybe<List<string>>;
}

const defaults = (params: Partial<CounterStateParams> = {}): CounterStateParams => ({
  count: valueOr(params.count, 0),
  animals: valueOr(params.animals, Maybe.nothing()),
});

export class CounterState extends Record(defaults()) implements CounterStateParams {
  count: number;
  animals: Maybe<List<string>>;

  constructor(params?: Partial<CounterStateParams>) {
    super(defaults(params));
  }

  with(values: Partial<CounterStateParams>) {
    return this.merge(values) as this;
  }
}


//// REDUCER ////

const initialState: CounterState = new CounterState();

export const counter = (
  state: CounterState = initialState,
  action: CounterActions,
): CounterState => {
  switch (action.type) {
    case UPDATE_COUNT:
      return state.with({
        count: action.count,
      });
    case CLEAR_COUNT:
      return state.with(defaults());
    default:
      return state;
  }
};
