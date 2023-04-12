import { SchedulerState, initSchedulerState, schedulerSliceReducer } from './scheduler-slice';
import { combineReducers } from 'redux';
import { ThunkDispatch } from 'redux-thunk';
import { ModalActions, ModalState, initModalState, modal } from 'state/modal';

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
