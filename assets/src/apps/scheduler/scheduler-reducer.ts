import { combineReducers } from 'redux';
import { ThunkDispatch } from 'redux-thunk';
import { ModalActions, ModalState, initModalState, modal } from 'state/modal';
import { SchedulerState, initSchedulerState, schedulerSliceReducer } from './scheduler-slice';

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
