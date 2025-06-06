import React, { useCallback, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useBackdropModal } from 'components/misc/BackdropModal';
import { Alert } from '../../components/misc/Alert';
import { usePromptModal } from '../../components/misc/PromptModal';
import { ContextMenuProvider } from './ContextMenuController';
import { ErrorDisplay } from './ErrorDisplay';
import { ScheduleGrid } from './ScheduleGrid';
import { ScheduleSaveBar } from './SchedulerSaveBar';
import { WeekDayPicker } from './WeekdayPicker';
import { hasUnsavedChanges } from './schedule-selectors';
import { StringDate, resetSchedule } from './scheduler-slice';
import {
  clearSectionSchedule,
  scheduleAppFlushChanges,
  scheduleAppStartup,
} from './scheduling-thunk';

export interface SchedulerProps {
  start_date: StringDate;
  end_date: StringDate;
  preferred_scheduling_time: string;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
  wizard_mode: boolean;
  edit_section_details_url: string;
}

export enum ViewMode {
  SCHEDULE = 'schedule',
  AGENDA = 'agenda',
}

export const ScheduleEditor: React.FC<SchedulerProps> = ({
  start_date,
  end_date,
  title,
  section_slug,
  display_curriculum_item_numbering,
  wizard_mode,
  edit_section_details_url,
  preferred_scheduling_time,
}) => {
  const dispatch = useDispatch();

  const unsavedChanges = useSelector(hasUnsavedChanges);
  const [validWeekdays, setValidWeekdays] = React.useState<boolean[]>([
    false,
    true,
    true,
    true,
    true,
    true,
    false,
  ]);

  const [viewMode, setViewMode] = React.useState<ViewMode | null>(null);

  const onModification = useCallback(() => {
    dispatch(scheduleAppFlushChanges());
  }, [dispatch]);

  const onReset = () => {
    dispatch(resetSchedule({ weekdays: validWeekdays }));
  };

  const onClear = () => {
    dispatch(clearSectionSchedule({ section_slug }));
  };

  const onViewSelected = (view: ViewMode) => {
    setViewMode(view);
    if (unsavedChanges) {
      showUnsavedModal();
      return;
    }
    changeView(view);
  };

  const changeView = (view: ViewMode) => {
    const url = new URL(window.location.href);
    url.pathname = `/sections/${section_slug}/preview/student_schedule`;
    if (view === ViewMode.AGENDA) {
      url.pathname = `/sections/${section_slug}/preview`;
    }
    window.open(url.href, '_blank');
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
        preferred_scheduling_time,
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

  const { Modal: clearModal, showModal: showClearModal } = useBackdropModal(
    <div>
      <p>
        This will clear all timelines and remove dates from assignments. This will also affect the
        information set in your assessment settings.
      </p>
    </div>,
    onClear,
    () => {},
    'Are you sure you want to clear the schedule?',
    'Clear Schedule',
    'Cancel',
  );

  const { Modal: unsavedModal, showModal: showUnsavedModal } = useBackdropModal(
    <div>
      <p>Please save your changes before viewing your schedule.</p>
    </div>,
    () => {},
    () => {
      dispatch(scheduleAppFlushChanges());
      changeView(viewMode || ViewMode.SCHEDULE);
    },
    'You have unsaved changes',
    'Keep editing',
    'View after saving',
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
    <ContextMenuProvider>
      <ErrorDisplay />
      {wizard_mode || <ScheduleSaveBar onSave={onModification} />}
      <div className="w-full flex justify-center flex-col">
        <ScheduleGrid
          startDate={start_date}
          endDate={end_date}
          onReset={showModal}
          onClear={showClearModal}
          onViewSelected={onViewSelected}
        />

        {Modal}
        {clearModal}
        {unsavedModal}
      </div>
    </ContextMenuProvider>
  );
};

declare global {
  interface Window {
    saveTorusSchedule: () => void;
  }
}
