import React, { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';

import { getSelectedId } from './schedule-selectors';
import { ScheduleGrid } from './ScheduleGrid';
import { HierarchyItemSrc, initSchedule, resetSchedule } from './scheduler-slice';
import { ScheduleSlideout } from './ScheduleSlideout';

export interface SchedulerProps {
  title: string;
  hierarchy: HierarchyItemSrc;
  start_date: string;
  end_date: string;
}

export const ScheduleEditor: React.FC<SchedulerProps> = ({
  title,
  hierarchy,
  start_date,
  end_date,
}) => {
  const dispatch = useDispatch();

  const onReset = () => {
    dispatch(resetSchedule());
  };

  useEffect(() => {
    dispatch(initSchedule({ hierarchy, start_date, end_date }));
  }, [dispatch, end_date, hierarchy, start_date]);

  const selectedId = useSelector(getSelectedId);

  return (
    <>
      <div>
        <button className="float-right" onClick={onReset}>
          Reset Schedule
        </button>
        <h1>{title}</h1>
      </div>

      <div className="flex flex-row gap-2">
        <div className="flex w-full overflow-x-auto border-r-2">
          <ScheduleGrid startDate={start_date} endDate={end_date} />
        </div>
        {selectedId && (
          <div className="w-48 bg-slate-400 h-full flex-shrink-0 flex-grow-0 slide-in-right">
            <ScheduleSlideout />
          </div>
        )}
      </div>
    </>
  );
};
