import React, {
  ChangeEvent,
  ChangeEventHandler,
  ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { debounce } from 'lodash';
import {
  dateWithTimeLabel,
  dateWithoutTimeLabel,
  stringToDateWithTime,
  stringToDateWithoutTime,
} from './date-utils';
import { getSelectedItem, hasUnsavedChanges, isSaving } from './schedule-selectors';
import {
  HierarchyItem,
  ScheduleItemType,
  SchedulingType,
  changeScheduleType,
  moveScheduleItem,
} from './scheduler-slice';

interface SaveIndicatorProps {
  onSave: () => void;
}

interface PageDetailEditorProps {
  selectedItem: HierarchyItem | null;
  dateInputValue: any;
  dateTimeInputValue: any;
  onChangeTypeHandler: ChangeEventHandler<HTMLSelectElement>;
  onChangeEndHandler: ChangeEventHandler<HTMLInputElement>;
  onChangeDueEndHandler: ChangeEventHandler<HTMLInputElement>;
  onChangeAvailableFromHandler: (event: ChangeEvent<HTMLInputElement> | null) => void;
}

const DateRangeView: React.FC<{ selectedItem: HierarchyItem | undefined | null }> = ({
  selectedItem,
}) => {
  if (!selectedItem) return null;

  return (
    <div className="flex flex-row gap-1 flex-grow-0 text-sm">
      <div className="text-ellipsis  overflow-hidden whitespace-nowrap text-right pt-3 mr-2">
        {selectedItem.title}:
      </div>
      <div className="w-52 pt-3">
        {dateWithoutTimeLabel(selectedItem.startDate)} -{' '}
        {dateWithoutTimeLabel(selectedItem.endDate)}
      </div>
    </div>
  );
};

const PageDetailEditor: React.FC<PageDetailEditorProps> = ({
  selectedItem,
  dateInputValue,
  dateTimeInputValue,
  onChangeTypeHandler,
  onChangeEndHandler,
  onChangeDueEndHandler,
  onChangeAvailableFromHandler,
}) => {
  if (!selectedItem) return null;

  return (
    <FormRow>
      <ItemTitle>{selectedItem.title}:</ItemTitle>

      <InputColumn>
        {selectedItem.graded && (
          <InputRow>
            <InputLabel>Available From:</InputLabel>
            <InputField>
              <input
                className="form-control text-sm"
                type="datetime-local"
                onBlur={onChangeAvailableFromHandler}
                defaultValue={dateWithTimeLabel(selectedItem.startDateTime) || ''}
              />
            </InputField>
          </InputRow>
        )}
        <InputRow>
          <InputLabel>
            <select
              className="form-control text-sm"
              value={selectedItem.scheduling_type}
              onChange={onChangeTypeHandler}
            >
              <option value="read_by">Suggested by:</option>
              <option value="inclass_activity">In-Class Activity On:</option>
              <option value="due_by">Due By:</option>
            </select>
          </InputLabel>
          <InputField>
            {selectedItem.scheduling_type === 'due_by' || (
              <input
                className="form-control text-sm"
                type="date"
                onChange={onChangeEndHandler}
                value={dateInputValue}
              />
            )}

            {selectedItem.scheduling_type === 'due_by' && (
              <input
                className="form-control text-sm"
                type="datetime-local"
                onChange={onChangeDueEndHandler}
                value={dateTimeInputValue}
              />
            )}
          </InputField>
        </InputRow>
      </InputColumn>
    </FormRow>
  );
};

const FormRow: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="flex flex-row gap-1 flex-grow-0 text-sm justify-center">{children}</div>
);

const InputColumn: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="flex flex-col gap-1 flex-grow-0 my-auto">{children}</div>
);

const ItemTitle: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="text-ellipsis text-sm overflow-hidden whitespace-nowrap text-right mr-5 w-40 my-auto font-bold">
    {children}
  </div>
);

const InputRow: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="flex flex-row gap-1 flex-grow-0  ">{children}</div>
);

const InputLabel: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="w-40 pt-0.5">{children}</div>
);

const InputField: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="pt-0.5">{children}</div>
);

export const ScheduleSaveBar: React.FC<SaveIndicatorProps> = ({ onSave }) => {
  const unsavedChanges = useSelector(hasUnsavedChanges);
  const selectedItem = useSelector(getSelectedItem);
  const saving = useSelector(isSaving);
  const dispatch = useDispatch();
  const [dateInputValue, setDateInputValue] = useState('');
  const [dateTimeInputValue, setDateTimeInputValue] = useState('');

  useEffect(() => {
    setDateInputValue(selectedItem ? dateWithoutTimeLabel(selectedItem.endDate) || '' : '');
    setDateTimeInputValue(selectedItem ? dateWithTimeLabel(selectedItem.endDateTime) || '' : '');
  }, [selectedItem]);

  const debouncedEndUpdate = useRef(
    debounce((newValue, currentSelectedItem) => {
      const target = newValue ? stringToDateWithoutTime(newValue) : null;
      if (!currentSelectedItem) return;

      dispatch(
        moveScheduleItem({
          itemId: currentSelectedItem.id,
          startDate: currentSelectedItem.startDateTime || currentSelectedItem.startDate,
          endDate: target,
        }),
      );
    }, 700),
  ).current;

  const debouncedDueEndUpdate = useRef(
    debounce((newValue, currentSelectedItem) => {
      const target = newValue ? stringToDateWithTime(newValue) : null;
      if (!currentSelectedItem) return;

      dispatch(
        moveScheduleItem({
          itemId: currentSelectedItem.id,
          startDate: currentSelectedItem.startDateTime || currentSelectedItem.startDate,
          endDate: target,
        }),
      );
    }, 700),
  ).current;

  useEffect(() => {
    return () => {
      debouncedEndUpdate.cancel();
      debouncedDueEndUpdate.cancel();
    };
  }, [debouncedEndUpdate, debouncedDueEndUpdate]);

  const onChangeEndHandler = (e) => {
    const newValue = e.target.value;
    setDateInputValue(newValue);

    const currentSelectedItem = selectedItem;
    debouncedEndUpdate(newValue, currentSelectedItem);
  };

  const onChangeDueEndHandler = (e) => {
    const newValue = e.target.value;
    setDateTimeInputValue(newValue);

    const currentSelectedItem = selectedItem;
    debouncedDueEndUpdate(newValue, currentSelectedItem);
  };

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

  const onChangeAvailableFromHandler = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const newDate = e.target.value;
      const target = newDate ? stringToDateWithTime(newDate) : null;
      if (!selectedItem) return;
      dispatch(
        moveScheduleItem({
          itemId: selectedItem.id,
          startDate: target,
          endDate: selectedItem.endDateTime || selectedItem.endDate,
        }),
      );
    },
    [dispatch, selectedItem],
  );

  const pageIsSelected = selectedItem && selectedItem.resource_type_id === ScheduleItemType.Page;
  if (!unsavedChanges && !saving && !pageIsSelected) return null;
  return (
    <div className="fixed p-4 pt-3 bottom-0 left-0 z-50 bg-body w-full flex border-t-gray-300 border-t h-24 dark:bg-slate-800">
      {pageIsSelected || <DateRangeView selectedItem={selectedItem} />}
      {pageIsSelected && (
        <PageDetailEditor
          onChangeDueEndHandler={onChangeDueEndHandler}
          onChangeEndHandler={onChangeEndHandler}
          onChangeTypeHandler={onChangeTypeHandler}
          onChangeAvailableFromHandler={onChangeAvailableFromHandler}
          selectedItem={selectedItem}
          dateInputValue={dateInputValue}
          dateTimeInputValue={dateTimeInputValue}
        />
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
              className="bg-delivery-primary px-5 py-3 text-delivery-body rounded-md text-ellipsis overflow-hidden whitespace-nowrap h-12"
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
