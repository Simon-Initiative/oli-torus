import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { dateWithoutTimeLabel, stringToDateWithoutTime } from './date-utils';
import { getSchedule, getSelectedItem } from './schedule-selectors';
import {
  moveScheduleItem,
  getScheduleItem,
  HierarchyItem,
  ScheduleItemType,
} from './scheduler-slice';

type StringDateChangeHandler = (val: string | null) => void;
interface SlideoutItemParams {
  item: HierarchyItem;

  onChangeEnd: StringDateChangeHandler;
}

const SlideoutItem: React.FC<SlideoutItemParams> = ({ item, onChangeEnd }) => {
  const onChangeEndHandler = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      onChangeEnd(e.target.value);
    },
    [onChangeEnd],
  );

  return (
    <li className="m-1 p-1 bg-slate-200 rounded-sm shadow-sm">
      <label className="font-bold">{item.title}</label>

      <div className="form-label-group">
        <div className="d-flex justify-content-between">
          <label>Complete By:</label>
        </div>

        <input
          className="form-control text-sm"
          type="date"
          onChange={onChangeEndHandler}
          value={dateWithoutTimeLabel(item.endDate) || ''}
        />
      </div>
    </li>
  );
};

const notEmpty = <TValue,>(value: TValue | null | undefined): value is TValue => !!value;

export const ScheduleSlideout: React.FC<{ onModification: () => void }> = ({ onModification }) => {
  const selectedItem = useSelector(getSelectedItem);
  const schedule = useSelector(getSchedule);
  const dispatch = useDispatch();

  const onChangeEndDate = (child: HierarchyItem) => (newDate: string | null) => {
    const target = newDate ? stringToDateWithoutTime(newDate) : null;
    debugger;
    dispatch(
      moveScheduleItem({
        itemId: child.id,
        startDate: child.startDate,
        endDate: target,
      }),
    );
    onModification();
  };

  if (!selectedItem) return null;

  return (
    <div>
      {selectedItem.title} {selectedItem.numbering_index}
      <ul className=" ">
        {selectedItem.children
          .map((itemId) => getScheduleItem(itemId, schedule))
          .filter(notEmpty)
          .filter((child) => child.resource_type_id === ScheduleItemType.Page)
          .map((child) => (
            <SlideoutItem
              onChangeEnd={onChangeEndDate(child)}
              key={child.resource_id}
              item={child}
            />
          ))}
      </ul>
    </div>
  );
};
