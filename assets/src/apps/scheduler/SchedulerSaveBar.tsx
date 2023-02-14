import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  changeScheduleType,
  moveScheduleItem,
  ScheduleItemType,
  SchedulingType,
} from './scheduler-slice';
import { getSelectedItem, hasUnsavedChanges, isSaving } from './schedule-selectors';
import {
  dateWithoutTimeLabel,
  dateWithTimeLabel,
  stringToDateWithoutTime,
  stringToDateWithTime,
} from './date-utils';

interface SaveIndicatorProps {
  onSave: () => void;
}

export const ScheduleSaveBar: React.FC<SaveIndicatorProps> = ({ onSave }) => {
  const unsavedChanges = useSelector(hasUnsavedChanges);
  const selectedItem = useSelector(getSelectedItem);
  const saving = useSelector(isSaving);
  const dispatch = useDispatch();
  const onChangeTypeHandler = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) => {
      if (!selectedItem) return;
      const newType = e.target.value as SchedulingType;
      dispatch(
        changeScheduleType({
          itemId: selectedItem.id,
          type: newType,
        }),
      );
    },
    [dispatch, selectedItem],
  );

  const onChangeEndHandler = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const newDate = e.target.value;
      const target = newDate ? stringToDateWithoutTime(newDate) : null;
      if (!selectedItem) return;
      dispatch(
        moveScheduleItem({
          itemId: selectedItem.id,
          startDate: selectedItem.startDate,
          endDate: target,
        }),
      );
    },
    [dispatch, selectedItem],
  );

  const onChangeDueEndHandler = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      // End date changing includes time
      const newDate = e.target.value;
      const target = newDate ? stringToDateWithTime(newDate) : null;
      if (!selectedItem) return;
      dispatch(
        moveScheduleItem({
          itemId: selectedItem.id,
          startDate: selectedItem.startDate,
          endDate: target,
        }),
      );
    },
    [dispatch, selectedItem],
  );
  const pageIsSelected = selectedItem && selectedItem.resource_type_id === ScheduleItemType.Page;
  if (!unsavedChanges && !saving && !pageIsSelected) return null;
  return (
    <div className="fixed p-4 bottom-0 left-0 z-50 bg-body w-full flex border-t-gray-300 border-t h-20">
      {pageIsSelected && (
        <div className="flex flex-row gap-1 flex-grow-0 ">
          <div className="text-ellipsis text-sm overflow-hidden whitespace-nowrap text-right pt-3 mr-2">
            {selectedItem.title}:
          </div>
          <div className="w-52 pt-0.5">
            <select
              className="form-control text-sm"
              value={selectedItem.scheduling_type}
              onChange={onChangeTypeHandler}
            >
              <option value="read_by">Suggested by:</option>
              <option value="inclass_activity">In-Class Activity On:</option>
              <option value="due_by">Due By:</option>
            </select>
          </div>
          <div className="w-52 pt-0.5">
            {selectedItem.scheduling_type === 'due_by' || (
              <input
                className="form-control text-sm"
                type="date"
                onChange={onChangeEndHandler}
                value={dateWithoutTimeLabel(selectedItem.endDate) || ''}
              />
            )}

            {selectedItem.scheduling_type === 'due_by' && (
              <input
                className="form-control text-sm"
                type="datetime-local"
                onChange={onChangeDueEndHandler}
                value={dateWithTimeLabel(selectedItem.endDateTime) || ''}
              />
            )}
          </div>
        </div>
      )}
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
        {unsavedChanges && !saving && (
          <>
            <div className="inline-block pt-3 text-ellipsis text-sm overflow-hidden whitespace-nowrap">
              You have unsaved changes
            </div>
            <button
              className="bg-delivery-primary px-5 py-3 text-delivery-body rounded-md text-ellipsis overflow-hidden whitespace-nowrap"
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
