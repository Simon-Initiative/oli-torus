import React, { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { debounce } from 'lodash';

import { getSelectedId } from './schedule-selectors';
import { ScheduleGrid } from './ScheduleGrid';
import { resetSchedule, StringDate } from './scheduler-slice';
import { ScheduleSlideout } from './ScheduleSlideout';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';

export interface SchedulerProps {
  start_date: StringDate;
  end_date: StringDate;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
}

export const ScheduleEditor: React.FC<SchedulerProps> = ({
  start_date,
  end_date,
  title,
  section_slug,
  display_curriculum_item_numbering,
}) => {
  const dispatch = useDispatch();

  const onModification = debounce(() => {
    dispatch(scheduleAppFlushChanges());
  }, 3000);

  const onReset = () => {
    dispatch(resetSchedule());
    onModification();
  };

  useEffect(() => {
    dispatch(
      scheduleAppStartup({
        start_date,
        end_date,
        title,
        section_slug,
        display_curriculum_item_numbering,
      }),
    );
    onModification();
  }, [
    dispatch,
    display_curriculum_item_numbering,
    end_date,
    onModification,
    section_slug,
    start_date,
    title,
  ]);

  const selectedId = useSelector(getSelectedId);

  return (
    <>
      <div>
        <button className="float-right" onClick={onReset}>
          Reset Schedule
        </button>
        <h1>{title}</h1>
        <small>
          {start_date} {end_date}
        </small>
      </div>

      <div className="flex flex-row gap-2">
        <div className="flex w-full overflow-x-auto border-r-2">
          <ScheduleGrid onModification={onModification} startDate={start_date} endDate={end_date} />
        </div>
        {selectedId && (
          <div className="w-64  h-full flex-shrink-0 flex-grow-0 slide-in-right">
            <ScheduleSlideout onModification={onModification} />
          </div>
        )}
      </div>
    </>
  );
};
