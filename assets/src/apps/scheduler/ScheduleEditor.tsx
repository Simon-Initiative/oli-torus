import React, { useCallback, useEffect, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useBackdropModal } from 'components/misc/BackdropModal';
import { useMultiStepModal } from 'components/misc/MultiStepModal';
import { Alert } from '../../components/misc/Alert';
import { ContextMenuProvider } from './ContextMenuController';
import { ErrorDisplay } from './ErrorDisplay';
import { ScheduleGrid } from './ScheduleGrid';
import { ScheduleSaveBar } from './SchedulerSaveBar';
import { WeekDayPicker } from './WeekdayPicker';
import { assessmentLayoutType, hasUnsavedChanges } from './schedule-selectors';
import {
  AssessmentLayoutType,
  StringDate,
  resetSchedule,
  setAssessmentLayoutType,
} from './scheduler-slice';
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
  agenda: boolean;
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
  agenda,
}) => {
  const dispatch = useDispatch();

  const unsavedChanges = useSelector(hasUnsavedChanges);
  const assessmentLayout = useSelector(assessmentLayoutType);

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
  const pendingNavigationUrl = useRef<string | null>(null);
  const navigationEventListener = useRef<((e: Event) => void) | null>(null);
  const showNavigationWarningModalRef = useRef<(() => void) | null>(null);
  const allowNavigation = useRef<boolean>(false);

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

  const handlePendingNavigation = () => {
    if (pendingNavigationUrl.current) {
      // Set flag to allow navigation without showing browser warning
      allowNavigation.current = true;
      window.location.href = pendingNavigationUrl.current;
      pendingNavigationUrl.current = null;
    }
  };

  const interceptNavigation = useCallback(
    (e: Event) => {
      if (!unsavedChanges) return;

      e.preventDefault();
      e.stopPropagation();

      const target = e.target as HTMLElement;
      const link = target.closest('a');

      if (link) {
        pendingNavigationUrl.current = link.href;
        if (showNavigationWarningModalRef.current) {
          showNavigationWarningModalRef.current();
        }
      }
    },
    [unsavedChanges],
  );

  // Set up navigation interception for tabs and breadcrumbs
  useEffect(() => {
    const setupNavigationGuards = () => {
      // Find tab navigation elements
      const tabLinks = document.querySelectorAll('#tabs-tab a');
      const breadcrumbLinks = document.querySelectorAll('.breadcrumb a');

      // Remove existing listeners
      if (navigationEventListener.current) {
        Array.from(tabLinks).forEach((link) => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
        Array.from(breadcrumbLinks).forEach((link) => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
      }

      // Add new listeners
      navigationEventListener.current = interceptNavigation;
      Array.from(tabLinks).forEach((link) => {
        // Skip the current schedule tab
        if (link.getAttribute('href')?.includes('/schedule')) return;

        link.addEventListener('click', navigationEventListener.current as EventListener);
      });
      Array.from(breadcrumbLinks).forEach((link) => {
        link.addEventListener('click', navigationEventListener.current as EventListener);
      });
    };

    // Setup navigation guards after a short delay to ensure DOM is ready
    const timer = setTimeout(setupNavigationGuards, 100);

    return () => {
      clearTimeout(timer);
      if (navigationEventListener.current) {
        const tabLinks = document.querySelectorAll('#tabs-tab a');
        const breadcrumbLinks = document.querySelectorAll('.breadcrumb a');
        Array.from(tabLinks).forEach((link) => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
        Array.from(breadcrumbLinks).forEach((link) => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
      }
    };
  }, [interceptNavigation]);

  // Handle browser navigation (refresh, close tab, external navigation)
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      // Don't show warning if user already chose to leave via modal
      if (allowNavigation.current) {
        allowNavigation.current = false; // Reset flag
        return;
      }

      if (unsavedChanges) {
        e.preventDefault();
        e.returnValue = '';
        return '';
      }
    };

    const handlePopState = (e: PopStateEvent) => {
      if (unsavedChanges) {
        e.preventDefault();
        pendingNavigationUrl.current = window.location.href;
        if (showNavigationWarningModalRef.current) {
          showNavigationWarningModalRef.current();
        }
        // Push the current state back to prevent navigation
        history.pushState(null, '', window.location.href);
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    window.addEventListener('popstate', handlePopState);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
      window.removeEventListener('popstate', handlePopState);
    };
  }, [unsavedChanges]);

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
        agenda,
      }),
    );
  }, [dispatch, display_curriculum_item_numbering, end_date, section_slug, start_date, title]);

  const steps = [
    <div key="step-1">
      <div className="font-bold mb-4">Set Default Timeline</div>
      <div className="mb-4">Select the week days you want to consider for that schedule.</div>
      <WeekDayPicker weekdays={validWeekdays} onChange={setValidWeekdays} />
    </div>,
    <div key="step-3">
      <div className="font-bold mb-4">Set Default Layout</div>
      <div className="mb-4">
        Choose the default layout of your course schedule. You can later customize the schedule by
        interacting with the timeline or visiting the assessment settings.
      </div>
      <div className="flex flex-col space-y-4 mt-4 pl-2">
        <label className="flex items-start space-x-3 text-gray-700 dark:text-gray-200">
          <input
            type="radio"
            name="assessmentLayoutType"
            className="mt-1"
            checked={assessmentLayout === AssessmentLayoutType.NoDueDates}
            onChange={() => dispatch(setAssessmentLayoutType(AssessmentLayoutType.NoDueDates))}
          />
          <span className="leading-snug font-bold">Do not set assessment due dates</span>
        </label>

        <label className="flex items-start space-x-3 text-gray-700 dark:text-gray-200">
          <input
            type="radio"
            name="assessmentLayoutType"
            className="mt-1"
            checked={assessmentLayout === AssessmentLayoutType.ContentSequence}
            onChange={() => dispatch(setAssessmentLayoutType(AssessmentLayoutType.ContentSequence))}
          />
          <span className="leading-snug font-bold">
            Set assessment due dates according to the sequence of course content.
          </span>
        </label>

        <label className="flex items-start space-x-3 text-gray-700 dark:text-gray-200">
          <input
            type="radio"
            name="assessmentLayoutType"
            className="mt-1"
            checked={assessmentLayout === AssessmentLayoutType.EndOfEachSection}
            onChange={() =>
              dispatch(setAssessmentLayoutType(AssessmentLayoutType.EndOfEachSection))
            }
          />
          <span className="leading-snug font-bold">
            Set assessment due dates to the end of each section.
          </span>
        </label>
      </div>
    </div>,
  ];
  const stepTitles = ['Set Default Timeline', 'Set Default Layout'];

  const { showModal, Modal } = useMultiStepModal(
    steps,
    stepTitles,
    () => onReset(),
    () => console.log('Cancelled!'),
    {
      title: 'Schedule Preferences',
      finishText: 'Complete',
      nextText: 'Continue',
      backText: 'Back',
      allowBack: false,
    },
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

  const { Modal: navigationWarningModal, showModal: showNavigationWarningModal } = useBackdropModal(
    <div>
      <p>You have unsaved changes that will be lost if you leave this page.</p>
    </div>,
    () => {
      // Keep editing - just close the modal
      pendingNavigationUrl.current = null;
    },
    () => {
      // Leave without saving
      handlePendingNavigation();
    },
    'You have unsaved changes',
    'Keep editing',
    'Leave without saving',
  );

  // Set the ref so it can be used in the interceptNavigation callback
  useEffect(() => {
    showNavigationWarningModalRef.current = showNavigationWarningModal;
  }, [showNavigationWarningModal]);

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
          section_slug={section_slug}
          onReset={showModal}
          onClear={showClearModal}
          onViewSelected={onViewSelected}
        />

        {Modal}
        {clearModal}
        {unsavedModal}
        {navigationWarningModal}
      </div>
    </ContextMenuProvider>
  );
};

declare global {
  interface Window {
    saveTorusSchedule: () => void;
  }
}
