import { DateWithoutTime } from 'epoq';
import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useToggle } from '../../components/hooks/useToggle';
import { DayGeometry } from './date-utils';
import { DragBar } from './DragBar';
import { PageDragBar } from './PageDragBar';
import { getSchedule, getSelectedId } from './schedule-selectors';
import { ScheduleHeader } from './ScheduleHeader';

// import { SchedulePlaceholder } from './SchedulePlaceholder';
import {
  getScheduleItem,
  HierarchyItem,
  moveScheduleItem,
  ScheduleItemType,
  selectItem,
  unlockScheduleItem,
} from './scheduler-slice';

interface ScheduleLineProps {
  item: HierarchyItem;
  indent: number;
  dayGeometry: DayGeometry;
}

export const PageScheduleLine: React.FC<ScheduleLineProps> = ({ item, indent, dayGeometry }) => {
  const dispatch = useDispatch();
  const isSelected = useSelector(getSelectedId) === item.id;

  const onUnlock = useCallback(() => {
    dispatch(unlockScheduleItem({ itemId: item.id }));
  }, [dispatch, item.id]);

  const onSelect = useCallback(() => {
    if (isSelected) {
      dispatch(selectItem(null));
    } else {
      dispatch(selectItem(item.id));
    }
  }, [dispatch, item.id, isSelected]);

  const onChange = useCallback(
    (startDate: DateWithoutTime | null, endDate: DateWithoutTime) => {
      dispatch(moveScheduleItem({ itemId: item.id, startDate, endDate }));
    },
    [dispatch, item.id],
  );

  const rowClass = isSelected ? 'bg-green-50' : '';

  return (
    <>
      <tr className={rowClass}>
        <td className="w-1 border-r-0 cursor-pointer"></td>
        <td className="w-48" style={{ paddingLeft: (1 + indent) * 10 }} onClick={onSelect}>
          {item.manually_scheduled && (
            <span
              className="float-right"
              onClick={onUnlock}
              data-bs-toggle="tooltip"
              title="You have manually adjusted the dates on this. Click to unlock."
            >
              <i className="fa fa-lock fa-2xs"></i>
            </span>
          )}
          <span className="float-right">
            <i className="fa fa-file fa-2xs"></i>
          </span>
          {item.title}
        </td>

        <td className="relative p-0">
          <ScheduleHeader labels={false} dayGeometry={dayGeometry} />
          {item.endDate && (
            <PageDragBar
              onChange={onChange}
              endDate={item.endDate}
              manual={item.manually_scheduled}
              dayGeometry={dayGeometry}
              isContainer={false}
              isSingleDay={true}
            />
          )}
        </td>
      </tr>
    </>
  );
};
