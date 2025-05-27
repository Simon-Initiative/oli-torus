import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { DateWithoutTime } from 'epoq';
import { modeIsDark } from 'components/misc/DarkModeSelector';
import { PageDragBar } from './PageDragBar';
import { ScheduleHeader } from './ScheduleHeader';
import { DayGeometry } from './date-utils';
import { getSelectedId } from './schedule-selectors';
import { HierarchyItem, moveScheduleItem, selectItem } from './scheduler-slice';

interface ScheduleLineProps {
  item: HierarchyItem;
  index: number;
  indent: number;
  rowColor: string;
  dayGeometry: DayGeometry;
}

export const PageScheduleLine: React.FC<ScheduleLineProps> = ({
  item,
  index,
  indent,
  rowColor,
  dayGeometry,
}) => {
  const dispatch = useDispatch();
  const isSelected = useSelector(getSelectedId) === item.id;

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
        targetStartDate = new Date();
        targetStartDate.setFullYear(
          startDate.getFullYear(),
          startDate.getMonth(),
          startDate.getDate(),
        );
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

  const rowSelectColor = React.useMemo(
    () => (isSelected ? { backgroundColor: modeIsDark() ? '#0D2A4E' : '#effdf5' } : {}),
    [isSelected],
  );
  const labelClasses = item.scheduling_type === 'due_by' ? 'font-bold' : '';

  return (
    <>
      <tr style={rowSelectColor}>
        <td className="w-[1px] p-[2px] border-r-0" style={{ backgroundColor: rowColor }}></td>
        <td className={`w-64 ${labelClasses}`} onClick={onSelect}>
          <div style={{ paddingLeft: 20 + (1 + indent) * 10 }}>{item.title}</div>
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
