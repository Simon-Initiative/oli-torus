import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { dateWithoutTimeLabel, stringToDateWithoutTime } from './date-utils';
import { getSchedule, getSelectedItem } from './schedule-selectors';
import {
  HierarchyItem,
  ScheduleItemType,
  SchedulingType,
  changeScheduleType,
  getScheduleItem,
  moveScheduleItem,
  unlockScheduleItem,
} from './scheduler-slice';

type StringDateChangeHandler = (val: string | null) => void;
type ScheduleTypeChangeHandler = (val: SchedulingType) => void;
interface SlideoutItemParams {
  item: HierarchyItem;

  onChangeEnd: StringDateChangeHandler;
  onChangeType: ScheduleTypeChangeHandler;
  onUnlock: () => void;
}

const GradedIcon: React.FC<{ graded: boolean }> = ({ graded }) =>
  graded ? (
    <span data-bs-toggle="tooltip" title="This is a graded page">
      <i className="fa-solid fa-file-pen fa-lg mx-2 text-gray-700"></i>
    </span>
  ) : (
    <span data-bs-toggle="tooltip" title="This is a practice page">
      <i className="fa-solid fa-file-lines fa-lg mx-2 text-gray-700"></i>
    </span>
  );

const SlideoutItem: React.FC<SlideoutItemParams> = ({
  item,
  onChangeEnd,
  onUnlock,
  onChangeType,
}) => {
  const onChangeTypeHandler = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) => {
      onChangeType(e.target.value as SchedulingType);
    },
    [onChangeType],
  );

  const onChangeEndHandler = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChangeEnd(e.target.value);
    },
    [onChangeEnd],
  );

  return (
    <li className="m-1 p-1 bg-gray-100 rounded-sm shadow-sm shadow-sm">
      <label className="font-bold p-1">
        <GradedIcon graded={item.graded} />

        {item.title}
        {item.manually_scheduled && (
          <span
            className="float-right"
            data-bs-toggle="tooltip"
            title="You have manually adjusted the dates on this. Click to unlock."
            onClick={onUnlock}
          >
            <i className="fa fa-lock"></i>
          </span>
        )}
      </label>

      <div className="form-label-group m-t">
        <div className="d-flex justify-content-between m-1 gap-2 flex-col">
          <select
            className="form-control"
            value={item.scheduling_type}
            onChange={onChangeTypeHandler}
          >
            <option value="read_by">Read by:</option>
            <option value="inclass_activity">In-Class Activity On:</option>
          </select>
          <input
            className="form-control text-sm"
            type="date"
            onChange={onChangeEndHandler}
            value={dateWithoutTimeLabel(item.endDate) || ''}
          />
        </div>
      </div>
    </li>
  );
};

const notEmpty = <TValue,>(value: TValue | null | undefined): value is TValue => !!value;

export const ScheduleSlideout: React.FC = () => {
  const selectedItem = useSelector(getSelectedItem);
  const schedule = useSelector(getSchedule);
  const dispatch = useDispatch();

  const onChangeType = (item: HierarchyItem) => (newType: SchedulingType) => {
    if (!item) return;
    dispatch(
      changeScheduleType({
        itemId: item.id,
        type: newType,
      }),
    );
  };

  const onUnlock = (item: HierarchyItem) => () => {
    if (!item) return;
    dispatch(
      unlockScheduleItem({
        itemId: item.id,
      }),
    );
  };

  const onChangeEndDate = (child: HierarchyItem) => (newDate: string | null) => {
    const target = newDate ? stringToDateWithoutTime(newDate) : null;
    dispatch(
      moveScheduleItem({
        itemId: child.id,
        startDate: child.startDate,
        endDate: target,
      }),
    );
  };

  if (!selectedItem) return null;

  return (
    <div>
      <div className="pl-1">
        {selectedItem.title} {selectedItem.numbering_index}
      </div>

      <ul className=" ">
        {selectedItem.children
          .map((itemId) => getScheduleItem(itemId, schedule))
          .filter(notEmpty)
          .filter((child) => child.resource_type_id === ScheduleItemType.Page)
          .map((child) => (
            <SlideoutItem
              onUnlock={onUnlock(child)}
              onChangeType={onChangeType(child)}
              onChangeEnd={onChangeEndDate(child)}
              key={child.resource_id}
              item={child}
            />
          ))}
      </ul>
    </div>
  );
};
