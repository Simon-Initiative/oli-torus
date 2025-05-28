import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { DateWithoutTime } from 'epoq';
import { modeIsDark } from 'components/misc/DarkModeSelector';
import { DragBar } from './DragBar';
import { PageScheduleLine } from './PageScheduleLine';
import { ScheduleHeader } from './ScheduleHeader';
import { DayGeometry } from './date-utils';
import {
  getSchedule,
  getSelectedId,
  shouldDisplayCurriculumItemNumbering,
} from './schedule-selectors';
import {
  HierarchyItem,
  ScheduleItemType,
  getScheduleItem,
  isContainerExpanded,
  moveScheduleItem,
  selectItem,
  toggleContainer,
} from './scheduler-slice';

interface ScheduleLineProps {
  item: HierarchyItem;
  index: number;
  indent: number;
  rowColor: string;
  dayGeometry: DayGeometry;
}

export const ScheduleLine: React.FC<ScheduleLineProps> = ({
  item,
  index,
  indent,
  rowColor,
  dayGeometry,
}) => {
  return item.resource_type_id === ScheduleItemType.Page ? (
    <PageScheduleLine
      item={item}
      index={index}
      indent={indent}
      rowColor={rowColor}
      dayGeometry={dayGeometry}
    />
  ) : (
    <ContainerScheduleLine
      item={item}
      index={index}
      indent={indent}
      rowColor={rowColor}
      dayGeometry={dayGeometry}
    />
  );
};

const ContainerScheduleLine: React.FC<ScheduleLineProps> = ({
  item,
  index,
  indent,
  rowColor,
  dayGeometry,
}) => {
  const dispatch = useDispatch();
  const expanded = useSelector((state) => isContainerExpanded(state, item.id));
  const toggleExpanded = () => dispatch(toggleContainer(item.id));
  const isSelected = useSelector(getSelectedId) === item.id;
  const schedule = useSelector(getSchedule);
  const showNumbers = useSelector(shouldDisplayCurriculumItemNumbering);

  const onSelect = useCallback(() => {
    dispatch(selectItem(item.id));
  }, [dispatch, item.id]);

  const onChange = useCallback(
    (startDate: DateWithoutTime, endDate: DateWithoutTime) => {
      dispatch(moveScheduleItem({ itemId: item.id, startDate, endDate }));
    },
    [dispatch, item.id],
  );

  const containerChildren = item.children
    .map((itemId) => getScheduleItem(itemId, schedule))
    .filter((item) => item?.resource_type_id === ScheduleItemType.Container) as HierarchyItem[];

  const pageChildren = item.children
    .map((itemId) => getScheduleItem(itemId, schedule))
    .filter((item) => item?.resource_type_id === ScheduleItemType.Page) as HierarchyItem[];

  const onStartDrag = useCallback(() => {
    dispatch(selectItem(item.id));
  }, [dispatch, item.id]);

  const rowSelectColor = React.useMemo(
    () => (isSelected ? { backgroundColor: modeIsDark() ? '#0D2A4E' : '#effdf5' } : {}),
    [isSelected],
  );
  const labelClasses = item.scheduling_type === 'due_by' ? 'font-bold' : '';

  const plusMinusIcon = expanded ? 'fa-regular fa-square-minus' : 'fa-regular fa-square-plus';
  const chevronIcon = expanded ? 'fa-solid fa-chevron-up' : 'fa-solid fa-chevron-down';

  return (
    <>
      <tr style={rowSelectColor}>
        <td className="border-r-0 w-[1px] !p-[2px]" style={{ backgroundColor: rowColor }}></td>
        <td
          className={`w-48 ${labelClasses} font-bold`}
          style={{ paddingLeft: (1 + indent) * 10 }}
          onClick={onSelect}
        >
          {item.children.length > 0 && indent > 0 && (
            <div className="inline mr-1" onClick={toggleExpanded} style={{ display: 'inline' }}>
              <i className={plusMinusIcon} />
            </div>
          )}
          {showNumbers ? item.numbering_index + '.' : ''} {item.title}
          {item.children.length > 0 && indent === 0 && (
            <div
              className="inline mr-1 float-right"
              onClick={toggleExpanded}
              style={{ display: 'inline' }}
            >
              <i className={chevronIcon} />
            </div>
          )}
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
              color={rowColor}
              dayGeometry={dayGeometry}
              isContainer={expanded && containerChildren.length > 0}
            />
          )}
        </td>
      </tr>

      {expanded &&
        containerChildren.map((child, cindex) => (
          <ScheduleLine
            key={child?.resource_id}
            index={1 + index + cindex}
            item={child}
            indent={indent + 1}
            rowColor={rowColor}
            dayGeometry={dayGeometry}
          />
        ))}

      {expanded &&
        pageChildren.map((child, cindex) => (
          <PageScheduleLine
            key={child?.resource_id}
            index={1 + index + cindex}
            item={child}
            indent={indent + 1}
            rowColor={rowColor}
            dayGeometry={dayGeometry}
          />
        ))}
    </>
  );
};
