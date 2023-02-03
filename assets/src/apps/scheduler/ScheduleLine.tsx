import { DateWithoutTime } from 'epoq';
import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useToggle } from '../../components/hooks/useToggle';
import { DayGeometry } from './date-utils';
import { DragBar } from './DragBar';
import { getSchedule, getSelectedId } from './schedule-selectors';
import { ScheduleHeader } from './ScheduleHeader';
// import { SchedulePlaceholder } from './SchedulePlaceholder';
import {
  getScheduleItem,
  HierarchyItem,
  moveScheduleItem,
  ScheduleItemType,
  selectItem,
} from './scheduler-slice';

interface ScheduleLineProps {
  item: HierarchyItem;
  indent: number;
  dayGeometry: DayGeometry;
  onModification: () => void;
}

export const ScheduleLine: React.FC<ScheduleLineProps> = ({
  item,
  indent,
  dayGeometry,
  onModification,
}) => {
  const [expanded, toggleExpanded] = useToggle(false);
  const dispatch = useDispatch();
  const isSelected = useSelector(getSelectedId) === item.id;
  const schedule = useSelector(getSchedule);

  const onSelect = useCallback(() => {
    if (isSelected) {
      dispatch(selectItem(null));
    } else {
      dispatch(selectItem(item.id));
    }
  }, [dispatch, item.id, isSelected]);

  const onChange = useCallback(
    (startDate: DateWithoutTime, endDate: DateWithoutTime) => {
      // const newStart = leftToDate(left, dayGeometry);
      // const newEnd = leftToDate(left + width - 1, dayGeometry);

      // if (!newStart || !newEnd) {
      //   return;
      // }
      // console.info('onChange', { left, width });
      // console.info(`Start: ${item.start_date} => ${newStart.date}`);
      // console.info(`End: ${item.end_date} => ${newEnd.date}`);
      dispatch(moveScheduleItem({ itemId: item.id, startDate, endDate }));
      onModification();
    },
    [dispatch, item.id, onModification],
  );

  // const onStartDrag = useCallback(() => {
  //   //console.info('Start drag', geometry);
  //   dispatch(selectItem(item.id));
  // }, [dispatch, item.id]);

  const containerChildren = item.children
    .map((itemId) => getScheduleItem(itemId, schedule))
    .filter((item) => item?.resource_type_id === ScheduleItemType.Container) as HierarchyItem[];
  const expansionIcon = containerChildren.length === 0 ? null : expanded ? '-' : '+';

  const rowClass = isSelected ? 'bg-green-50' : '';

  return (
    <>
      <tr className={rowClass}>
        <td className="w-1 border-r-0 cursor-pointer " onClick={toggleExpanded}>
          {expansionIcon}
        </td>
        <td className="w-48" style={{ paddingLeft: (1 + indent) * 10 }} onClick={onSelect}>
          {item.title} {item.numbering_index}
        </td>
        <td className="relative p-0">
          <ScheduleHeader labels={false} dayGeometry={dayGeometry} />
          {item.startDate && item.endDate && (
            <DragBar
              // onStartDrag={onStartDrag}
              onChange={onChange}
              startDate={item.startDate}
              endDate={item.endDate}
              manual={item.manually_scheduled}
              dayGeometry={dayGeometry}
              isContainer={expanded && containerChildren.length > 0}
            />
          )}
        </td>
      </tr>

      {expanded &&
        containerChildren.map((child) => (
          <ScheduleLine
            key={child?.resource_id}
            item={child}
            indent={indent + 1}
            dayGeometry={dayGeometry}
            onModification={onModification}
          />
        ))}

      {/* {expanded || containerChildren.map((_, i) => <SchedulePlaceholder key={i} />)} */}
    </>
  );
};
