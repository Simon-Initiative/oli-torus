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
  unlockScheduleItem,
} from './scheduler-slice';

interface ScheduleLineProps {
  item: HierarchyItem;
  indent: number;
  dayGeometry: DayGeometry;
}

export const ScheduleLine: React.FC<ScheduleLineProps> = ({ item, indent, dayGeometry }) => {
  const [expanded, toggleExpanded] = useToggle(false);
  const dispatch = useDispatch();
  const isSelected = useSelector(getSelectedId) === item.id;
  const schedule = useSelector(getSchedule);

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
    (startDate: DateWithoutTime, endDate: DateWithoutTime) => {
      dispatch(moveScheduleItem({ itemId: item.id, startDate, endDate }));
    },
    [dispatch, item.id],
  );

  const containerChildren = item.children
    .map((itemId) => getScheduleItem(itemId, schedule))
    .filter((item) => item?.resource_type_id === ScheduleItemType.Container) as HierarchyItem[];

  const expansionIcon = containerChildren.length === 0 ? null : expanded ? '-' : '+';
  const hasPages = item.children.length != containerChildren.length;

  const onStartDrag = useCallback(() => {
    if (hasPages) {
      dispatch(selectItem(item.id));
    } else {
      dispatch(selectItem(null));
    }
  }, [dispatch, hasPages, item.id]);

  const rowClass = isSelected ? 'bg-green-50' : '';

  return (
    <>
      <tr className={rowClass}>
        <td className="w-1 border-r-0 cursor-pointer" onClick={toggleExpanded}>
          {expansionIcon}
        </td>
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
          {hasPages && (
            <span
              className="float-right"
              data-bs-toggle="tooltip"
              title="View pages within this container"
            >
              <i className="fa fa-layer-group fa-2xs"></i>
            </span>
          )}
          {item.title} {item.numbering_index}
        </td>

        <td className="relative p-0">
          <ScheduleHeader labels={false} dayGeometry={dayGeometry} />
          {item.startDate && item.endDate && (
            <DragBar
              onStartDrag={onStartDrag}
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
          />
        ))}

      {/* {expanded || containerChildren.map((_, i) => <SchedulePlaceholder key={i} />)} */}
    </>
  );
};
