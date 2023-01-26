import { DateWithoutTime } from 'epoq';
import React, { useCallback } from 'react';
import { useDocumentMouseEvents } from '../../components/hooks/useDocumentMouseEvents';
import { useToggle } from '../../components/hooks/useToggle';
import { barGeometry, DayGeometry, leftToDate } from './date-utils';

interface DragBarProps {
  startDate: DateWithoutTime;
  endDate: DateWithoutTime;
  isContainer: boolean;
  dayGeometry: DayGeometry;
  onChange?: (start: DateWithoutTime, end: DateWithoutTime) => void;
  onStartDrag?: () => void;
}

export const DragBar: React.FC<DragBarProps> = ({
  startDate,
  endDate,
  onChange,
  isContainer,
  onStartDrag,
  dayGeometry,
  children,
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
        newEnd && setWorkingEnd(newEnd?.date);
      } else {
        const newStart = leftToDate(startingGeometry.left + delta, dayGeometry);
        newStart && setWorkingStart(newStart?.date);
      }
    } else if (isDragging) {
      const newStart = leftToDate(startingGeometry.left + delta, dayGeometry);
      if (!newStart) return;
      const originalDuration = workingEnd.getDaysSinceEpoch() - workingStart.getDaysSinceEpoch();
      const newEnd = new DateWithoutTime(newStart.date.getDaysSinceEpoch() + originalDuration);
      setWorkingStart(newStart.date);
      setWorkingEnd(newEnd);
    }
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
    (_e: React.MouseEvent | MouseEvent) => {
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

  const barStyles = {
    left: geometry.left,
    width: geometry.width,
  };

  return isContainer ? (
    <div
      onMouseDown={startDrag}
      className=" absolute border-t-4 border-black h-3 top-3 cursor-move flex flex-row justify-between"
      style={barStyles}
    >
      <div
        onMouseDown={startResize('left')}
        className="w-1 inline-block h-full bg-black cursor-col-resize"
      ></div>
      <div
        onMouseDown={startResize('right')}
        className="w-1 inline-block h-full bg-black cursor-col-resize"
      ></div>
    </div>
  ) : (
    <div
      onMouseDown={startDrag}
      className="rounded absolute bg-sky-500 h-7 top-1.5 flex flex-row justify-between p-0.5 cursor-move"
      style={barStyles}
    >
      <div
        onMouseDown={startResize('left')}
        className="w-0.5 inline-block h-full bg-sky-300 cursor-col-resize"
      ></div>
      {children}
      <div
        onMouseDown={startResize('right')}
        className="w-0.5 inline-block h-full bg-sky-300 cursor-col-resize"
      ></div>
    </div>
  );
};
