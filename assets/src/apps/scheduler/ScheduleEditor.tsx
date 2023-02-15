import React, { useCallback, useEffect } from 'react';
import { useDispatch } from 'react-redux';
import { usePromptModal } from '../../components/misc/PromptModal';
import { ErrorDisplay } from './ErrorDisplay';
import { ScheduleGrid } from './ScheduleGrid';
import { resetSchedule, StringDate } from './scheduler-slice';
import { ScheduleSaveBar } from './SchedulerSaveBar';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';

export interface SchedulerProps {
  start_date: StringDate;
  end_date: StringDate;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
  wizard_mode: boolean;
}

export const ScheduleEditor: React.FC<SchedulerProps> = ({
  start_date,
  end_date,
  title,
  section_slug,
  display_curriculum_item_numbering,
  wizard_mode,
}) => {
  const dispatch = useDispatch();

  const onModification = useCallback(() => {
    dispatch(scheduleAppFlushChanges());
  }, [dispatch]);

  const onReset = () => {
    dispatch(resetSchedule());
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
  }, [dispatch, display_curriculum_item_numbering, end_date, section_slug, start_date, title]);

  const { Modal, showModal } = usePromptModal(
    'Are you sure you want to reset the schedule to the default values?',
    onReset,
  );

  return (
    <>
      <ErrorDisplay />
      {wizard_mode || <ScheduleSaveBar onSave={onModification} />}
      <div className="flex justify-end p-1 ">
        <button className=" text-delivery-primary uppercase underline" onClick={showModal}>
          Reset Timelines
        </button>
      </div>

      <div className="flex flex-row gap-2">
        <div className="flex w-full overflow-x-auto border-r-2">
          <ScheduleGrid startDate={start_date} endDate={end_date} />
        </div>
      </div>
      {Modal}
    </>
  );
};
