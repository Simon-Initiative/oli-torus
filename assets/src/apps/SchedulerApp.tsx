import { ScheduleEditor } from './scheduler/ScheduleEditor';

import { registerApplication } from './app';
import React from 'react';
import { configureStore } from '../state/store';
import { HierarchyItemSrc } from './scheduler/scheduler-slice';
import { Provider } from 'react-redux';
import { initState, schedulerAppReducer } from './scheduler/scheduler-reducer';

export interface SchedulerAppProps {
  title: string;
  hierarchy: HierarchyItemSrc;
  start_date: string;
  end_date: string;
}

const store = configureStore(initState(), schedulerAppReducer);

const ScheduleEditorApp: React.FC<SchedulerAppProps> = React.memo(
  ({ hierarchy, title, start_date, end_date }) => (
    <Provider store={store}>
      <ScheduleEditor
        title={title}
        hierarchy={hierarchy}
        start_date={start_date}
        end_date={end_date}
      />
    </Provider>
  ),
);

ScheduleEditorApp.displayName = 'ScheduleEditorApp';

registerApplication('ScheduleEditor', ScheduleEditorApp, false);
