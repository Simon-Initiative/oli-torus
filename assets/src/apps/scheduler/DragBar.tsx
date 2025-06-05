import React, { useCallback } from 'react';
import { DateWithoutTime } from 'epoq';
import { useDocumentMouseEvents } from '../../components/hooks/useDocumentMouseEvents';
import { useToggle } from '../../components/hooks/useToggle';
import { DayGeometry, barGeometry, leftToDate } from './date-utils';

interface DragBarProps {
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

  return (
    <>
      {isContainer ? (
        <div
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
          onMouseDown={startDrag}
          className="group rounded absolute h-7 top-1.5 flex flex-row justify-between p-0.5 cursor-grab"
          style={{
            left: geometry.left,
            width: geometry.width,
            backgroundColor: color,
          }}
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
