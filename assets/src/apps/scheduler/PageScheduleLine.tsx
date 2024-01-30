import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { DateWithoutTime } from 'epoq';
import { PageDragBar } from './PageDragBar';
import { ScheduleHeader } from './ScheduleHeader';
import { DayGeometry } from './date-utils';
import { getSelectedId } from './schedule-selectors';
// import { SchedulePlaceholder } from './SchedulePlaceholder';
import { HierarchyItem, moveScheduleItem, selectItem, unlockScheduleItem } from './scheduler-slice';

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
      // dispatch(selectItem(null));
    } else {
      dispatch(selectItem(item.id));
    }
  }, [dispatch, item.id, isSelected]);

  const onChange = useCallback(
    (startDate: DateWithoutTime | null, endDate: DateWithoutTime) => {
      let targetEndDate: Date | DateWithoutTime = endDate;
      let targetStartDate: Date | DateWithoutTime | null = startDate;

      if (item.startDateTime && startDate) {
        targetStartDate = new Date(2024, 1, 1);
        // Important: Important to set these in order
        targetStartDate.setFullYear(startDate.getFullYear());
        targetStartDate.setMonth(startDate.getMonth());
        targetStartDate.setDate(startDate.getDate());
        targetStartDate.setHours(
          item.startDateTime.getHours(),
          item.startDateTime.getMinutes(),
          item.startDateTime.getSeconds(),
        );

        console.info('PageScheduleLine::onChange', {
          startDate,
          item: item.startDateTime,
          targetStartDate,
        });
      }

      // On a drag, need to change the date, but preserve the end time if one exists.
      if (item.endDateTime) {
        targetEndDate = new Date();
        targetEndDate.setFullYear(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
        targetEndDate.setHours(
          item.endDateTime.getHours(),
          item.endDateTime.getMinutes(),
          item.endDateTime.getSeconds(),
        );
      }

      dispatch(
        moveScheduleItem({ itemId: item.id, startDate: targetStartDate, endDate: targetEndDate }),
      );
    },
    [item.startDateTime, item.endDateTime, item.id, dispatch],
  );

  const rowClass = isSelected ? 'bg-green-50' : '';
  const labelClasses = item.scheduling_type === 'due_by' ? 'font-bold' : '';

  return (
    <>
      <tr className={`${rowClass} `}>
        <td className={`w-64 ${labelClasses}`} colSpan={2} onClick={onSelect}>
          <div style={{ paddingLeft: 20 + (1 + indent) * 10 }}>
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
            {item.title}
          </div>
        </td>

        <td className="relative p-0">
          <ScheduleHeader labels={false} dayGeometry={dayGeometry} />

          <PageDragBar
            onChange={onChange}
            onStartDrag={onSelect}
            startDate={item.startDate}
            endDate={item.endDate}
            manual={item.manually_scheduled}
            dayGeometry={dayGeometry}
            isContainer={false}
            isSingleDay={true}
            isGraded={item.graded}
            schedulingType={item.scheduling_type}
          />
        </td>
      </tr>
    </>
  );
};
