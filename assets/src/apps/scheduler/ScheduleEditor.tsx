import React, { useCallback, useEffect, useRef } from 'react';
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
      window.location.href = pendingNavigationUrl.current;
      pendingNavigationUrl.current = null;
    }
  };

      const interceptNavigation = useCallback((e: Event) => {
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
  }, [unsavedChanges]);

  // Set up navigation interception for tabs and breadcrumbs
  useEffect(() => {
    const setupNavigationGuards = () => {
      // Find tab navigation elements
      const tabLinks = document.querySelectorAll('#tabs-tab a');
      const breadcrumbLinks = document.querySelectorAll('.breadcrumb a');

            // Remove existing listeners
      if (navigationEventListener.current) {
        Array.from(tabLinks).forEach(link => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
        Array.from(breadcrumbLinks).forEach(link => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
      }

      // Add new listeners
      navigationEventListener.current = interceptNavigation;
      Array.from(tabLinks).forEach(link => {
        // Skip the current schedule tab
        if (link.getAttribute('href')?.includes('/schedule')) return;

        link.addEventListener('click', navigationEventListener.current as EventListener);
      });
      Array.from(breadcrumbLinks).forEach(link => {
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
        Array.from(tabLinks).forEach(link => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
        Array.from(breadcrumbLinks).forEach(link => {
          link.removeEventListener('click', navigationEventListener.current as EventListener);
        });
      }
    };
  }, [interceptNavigation]);

  // Handle browser back button and other navigation
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
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
        showNavigationWarningModal();
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

  // Update the data-saved attribute for BeforeUnloadListener integration
  useEffect(() => {
    const container = document.getElementById('schedule-container');
    if (container) {
      container.setAttribute('data-saved', unsavedChanges ? 'false' : 'true');
    }
  }, [unsavedChanges]);

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
