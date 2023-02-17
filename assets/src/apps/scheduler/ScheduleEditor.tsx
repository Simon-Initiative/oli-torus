import React, { useCallback, useEffect } from 'react';
import { useDispatch } from 'react-redux';
import { Alert } from '../../components/misc/Alert';
import { usePromptModal } from '../../components/misc/PromptModal';
import { ErrorDisplay } from './ErrorDisplay';
import { ScheduleGrid } from './ScheduleGrid';
import { resetSchedule, StringDate } from './scheduler-slice';
import { ScheduleSaveBar } from './SchedulerSaveBar';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';
import { WeekDayPicker } from './WeekdayPicker';

export interface SchedulerProps {
  start_date: StringDate;
  end_date: StringDate;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
  wizard_mode: boolean;
  edit_section_details_url: string;
}

export const ScheduleEditor: React.FC<SchedulerProps> = ({
  start_date,
  end_date,
  title,
  section_slug,
  display_curriculum_item_numbering,
  wizard_mode,
  edit_section_details_url,
}) => {
  const dispatch = useDispatch();

  const [validWeekdays, setValidWeekdays] = React.useState<boolean[]>([
    false,
    true,
    true,
    true,
    true,
    true,
    false,
  ]);

  const onModification = useCallback(() => {
    dispatch(scheduleAppFlushChanges());
  }, [dispatch]);

  const onReset = () => {
    dispatch(resetSchedule({ weekdays: validWeekdays }));
  };

  // Set up a way the page can call into us to save, useful for the wizard mode when we don't have a save bar to click.
  useEffect(() => {
    window.saveTorusSchedule = () => {
      dispatch(scheduleAppFlushChanges());
      /* When we've successfully saved, we will do either a
           window.dispatchEvent(new Event('schedule-updated'))
           window.dispatchEvent(new Event('schedule-update-failed'));
         for the wizard to listen for.
      */
    };
  }, [dispatch]);

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
    <div>
      <p>
        This will reset all timelines to the default. Select the week days you want to consider for
        that schedule.
      </p>
      <WeekDayPicker weekdays={validWeekdays} onChange={setValidWeekdays} />
    </div>,

    onReset,
  );

  if (!start_date || !end_date) {
    return (
      <div className="container">
        <Alert variant="warning">
          <p>Your section must have a start and end date set before you can schedule it. </p>
          <p>
            Set these on the <a href={edit_section_details_url}> Edit Section Details</a> page.
          </p>
        </Alert>
      </div>
    );
  }

  return (
    <>
      <ErrorDisplay />
      {wizard_mode || <ScheduleSaveBar onSave={onModification} />}
      <div className="w-full flex justify-center flex-col">
        <ScheduleGrid startDate={start_date} endDate={end_date} onReset={showModal} />

        {Modal}
      </div>
    </>
  );
};

declare global {
  interface Window {
    saveTorusSchedule: () => void;
  }
}
