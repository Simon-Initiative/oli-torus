import { ThunkDispatch } from 'redux-thunk';

import { combineReducers } from 'redux';
import { ModalActions, ModalState, modal, initModalState } from 'state/modal';
import { initSchedulerState, schedulerSliceReducer, SchedulerState } from './scheduler-slice';

export interface SchedulerAppState {
  scheduler: SchedulerState;
  modal: ModalState;
}

type AllActions = ModalActions;

export type Dispatch = ThunkDispatch<SchedulerAppState, void, AllActions>;

export const schedulerAppReducer = combineReducers<SchedulerAppState>({
  scheduler: schedulerSliceReducer,
  modal,
});

export function initState(json: any = {}) {
  return {
    modal: initModalState(json),
    scheduler: initSchedulerState(),
  };
}
