import React, { useCallback, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { debounce } from 'lodash';

import { ScheduleGrid } from './ScheduleGrid';
import { resetSchedule, StringDate } from './scheduler-slice';
import { ScheduleSlideout } from './ScheduleSlideout';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';
import { hasUnsavedChanges, isSaving, selectedContainsPages } from './schedule-selectors';

export interface SchedulerProps {
  start_date: StringDate;
  end_date: StringDate;
  title: string;
  section_slug: string;
  display_curriculum_item_numbering: boolean;
  wizard_mode: boolean;
}
interface SaveIndicatorProps {
  onSave: () => void;
}
const SaveIndicator: React.FC<SaveIndicatorProps> = ({ onSave }) => {
  const unsavedChanges = useSelector(hasUnsavedChanges);
  const saving = useSelector(isSaving);
  if (!unsavedChanges && !saving) return null;
  return (
    <div className="fixed p-4  bottom-0 left-0 z-50 bg-body w-full flex border-t-gray-300 border-t">
      <div className="flex-grow" />
      <div className="flex gap-3 justify-center ">
        {saving && (
          <button
            disabled
            className="bg-delivery-primary-700 px-5 py-3 text-delivery-body rounded-md"
          >
            <span className="animate-spin">
              <i className="fa fa-spinner fa-spin"></i>
            </span>
            &nbsp; Saving...
          </button>
        )}
        {saving || (
          <>
            <div className="inline-block pt-2">You have unsaved changes</div>
            <button
              className="bg-delivery-primary px-5 py-3 text-delivery-body rounded-md"
              onClick={onSave}
            >
              Save Changes
            </button>
          </>
        )}
      </div>
    </div>
  );
};

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

  const showSlideout = useSelector(selectedContainsPages);

  return (
    <>
      {wizard_mode || <SaveIndicator onSave={onModification} />}
      <div className="flex justify-end p-1 ">
        <button className=" text-delivery-primary uppercase underline" onClick={onReset}>
          Reset Timelines
        </button>
      </div>

      <div className="flex flex-row gap-2">
        <div className="flex w-full overflow-x-auto border-r-2">
          <ScheduleGrid startDate={start_date} endDate={end_date} />
        </div>
        {showSlideout && (
          <div className="w-64 p-2 h-full border flex-shrink-0 flex-grow-0 slide-in-right rounded-lg shadow-lg">
            <ScheduleSlideout />
          </div>
        )}
      </div>
    </>
  );
};
