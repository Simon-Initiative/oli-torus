import React, { useCallback } from 'react';
import { useDispatch } from 'react-redux';
import { DateWithoutTime } from 'epoq';
import { useDocumentMouseEvents } from '../../components/hooks/useDocumentMouseEvents';
import { useToggle } from '../../components/hooks/useToggle';
import { ContextMenuItem } from './ContextMenu';
import { useContextMenu } from './ContextMenuController';
import { DayGeometry, barGeometry, leftToDate } from './date-utils';
import { VisibleHierarchyItem } from './schedule-selectors';
import { reAddScheduleItem, removeScheduleItem } from './scheduler-slice';

interface DragBarProps {
  item: VisibleHierarchyItem;
  startDate: DateWithoutTime;
  endDate: DateWithoutTime;
  isContainer: boolean;
  dayGeometry: DayGeometry;
  color: string;
  onChange?: (start: DateWithoutTime, end: DateWithoutTime) => void;
  onStartDrag?: () => void;
  manual: boolean;
}

export const DragBar: React.FC<DragBarProps> = ({
  item,
  startDate,
  endDate,
  onChange,
  isContainer,
  onStartDrag,
  dayGeometry,
  color,
  children,
  manual,
}) => {
  const [isDragging, , enableDrag, disableDrag] = useToggle();
  const [isResize, , enableResize, disableResize] = useToggle();
  const [resizeDirection, setResizeDirection] = React.useState<'left' | 'right'>('right');

  const [startingGeometry, setStartingGeometry] = React.useState({ left: 0, width: 0 });
  const [workingStart, setWorkingStart] = React.useState<DateWithoutTime>(new DateWithoutTime());
  const [workingEnd, setWorkingEnd] = React.useState<DateWithoutTime>(new DateWithoutTime());

  const [mouseDownX, setMouseDownX] = React.useState(0);

  const { showMenu, hideMenu } = useContextMenu();
  const dispatch = useDispatch();

  const menuItem = item.removed_from_schedule
    ? {
        label: 'Re-add item to Schedule',
        onClick: () => {
          hideMenu();
          dispatch(
            reAddScheduleItem({
              itemId: item.id,
            }),
          );
        },
      }
    : {
        label: 'Remove from Schedule',
        onClick: () => {
          hideMenu();
          dispatch(
            removeScheduleItem({
              itemId: item.id,
            }),
          );
        },
      };
  const menuItems: ContextMenuItem[] = [menuItem];

  const handleContextMenu = (e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    showMenu({ x: e.clientX, y: e.clientY }, menuItems);
  };

  const onMouseMove = (e: MouseEvent) => {
    const delta = e.clientX - mouseDownX;
    if (isResize) {
      if (resizeDirection === 'right') {
        const newEnd = leftToDate(
          startingGeometry.left + startingGeometry.width + delta,
          dayGeometry,
        );
        newEnd &&
          newEnd.date.getDaysSinceEpoch() >= workingStart.getDaysSinceEpoch() &&
          setWorkingEnd(newEnd?.date);
      } else {
        const newStart = leftToDate(startingGeometry.left + delta, dayGeometry);
        newStart &&
          newStart.date.getDaysSinceEpoch() <= workingEnd.getDaysSinceEpoch() &&
          setWorkingStart(newStart?.date);
      }
      const modified =
        workingStart.getDaysSinceEpoch() !== startDate.getDaysSinceEpoch() ||
        workingEnd.getDaysSinceEpoch() !== endDate.getDaysSinceEpoch();
      onChange && modified && onChange(workingStart, workingEnd);
    } else if (isDragging) {
      const newStart = leftToDate(startingGeometry.left + delta, dayGeometry);
      if (!newStart) return;
      const originalDuration = workingEnd.getDaysSinceEpoch() - workingStart.getDaysSinceEpoch();
      const newEnd = new DateWithoutTime(newStart.date.getDaysSinceEpoch() + originalDuration);
      setWorkingStart(newStart.date);
      setWorkingEnd(newEnd);
    }
    const modified =
      workingStart.getDaysSinceEpoch() !== startDate.getDaysSinceEpoch() &&
      workingEnd.getDaysSinceEpoch() !== endDate.getDaysSinceEpoch();

    onChange && modified && onChange(workingStart, workingEnd);
  };

  const startResize = useCallback(
    (direction: 'left' | 'right') => (e: React.MouseEvent) => {
      setMouseDownX(e.clientX);
      setResizeDirection(direction);
      setWorkingStart(startDate);
      setWorkingEnd(endDate);
      setStartingGeometry(barGeometry(dayGeometry, startDate, endDate));
      enableResize();
      e.stopPropagation();
    },
    [dayGeometry, enableResize, endDate, startDate],
  );

  const startDrag = useCallback(
    (e: React.MouseEvent) => {
      enableDrag();
      setMouseDownX(e.clientX);
      setWorkingStart(startDate);
      setWorkingEnd(endDate);
      setStartingGeometry(barGeometry(dayGeometry, startDate, endDate));
      onStartDrag && onStartDrag();
    },
    [dayGeometry, enableDrag, endDate, onStartDrag, startDate],
  );

  const stopDrag = useCallback(
    (e: React.MouseEvent | MouseEvent) => {
      disableDrag();
      disableResize();
      onChange && onChange(workingStart, workingEnd);
    },
    [disableDrag, disableResize, onChange, workingEnd, workingStart],
  );

  useDocumentMouseEvents(isDragging || isResize, undefined, stopDrag, onMouseMove);

  const geometry =
    isResize || isDragging
      ? barGeometry(dayGeometry, workingStart, workingEnd)
      : barGeometry(dayGeometry, startDate, endDate);

  const removedBackground = item.removed_from_schedule
    ? {
        left: geometry.left,
        width: geometry.width,
        background: `repeating-linear-gradient(
                -45deg,
                #ad2833,
                #ad2833 6px,
                transparent 6px,
                transparent 14px
            )`,
        border: `2px solid #ad2833`,
      }
    : {
        left: geometry.left,
        width: geometry.width,
        background: `${color} no-repeat fixed center`,
        border: `2px solid ${color}`,
      };
  return (
    <>
      {isContainer ? (
        <div
          onContextMenu={handleContextMenu}
          onMouseDown={startDrag}
          className="absolute border-t-4 h-3 top-3 cursor-grab flex flex-row justify-between"
          style={{
            left: geometry.left,
            width: geometry.width,
            borderTopColor: color,
          }}
        >
          <div
            onMouseDown={startResize('left')}
            className="w-1 inline-block h-full cursor-col-resize"
            style={{ backgroundColor: color }}
          ></div>
          <div
            onMouseDown={startResize('right')}
            className="w-1 inline-block h-full cursor-col-resize"
            style={{ backgroundColor: color }}
          ></div>
        </div>
      ) : (
        <div
          onContextMenu={handleContextMenu}
          onMouseDown={startDrag}
          className="group rounded absolute h-7 top-1.5 flex flex-row justify-between p-0.5 cursor-grab"
          style={removedBackground}
        >
          <div
            onMouseDown={startResize('left')}
            className="w-0.5 inline-block h-full group-hover:bg-delivery-primary-300 group-hover:dark:bg-delivery-primary-200 cursor-col-resize group-hover:dark:border-gray-400"
          ></div>
          {children}

          <div
            onMouseDown={startResize('right')}
            className="w-0.5 inline-block h-full group-hover:bg-delivery-primary-300 group-hover:dark:bg-delivery-primary-200 cursor-col-resize group-hover:dark:border-gray-400"
          ></div>
        </div>
      )}
    </>
  );
};
