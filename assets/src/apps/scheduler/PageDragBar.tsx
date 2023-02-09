import { DateWithoutTime } from 'epoq';
import React, { useCallback } from 'react';
import { useDocumentMouseEvents } from '../../components/hooks/useDocumentMouseEvents';
import { useToggle } from '../../components/hooks/useToggle';
import { barGeometry, dateWithoutTimeLabel, DayGeometry, leftToDate } from './date-utils';

interface DragBarProps {
  endDate: DateWithoutTime;
  isContainer: boolean;
  dayGeometry: DayGeometry;
  onChange?: (start: DateWithoutTime | null, end: DateWithoutTime) => void;
  onStartDrag?: () => void;
  manual: boolean;
  isSingleDay?: boolean;
}

export const PageDragBar: React.FC<DragBarProps> = ({
  endDate,
  onChange,
  onStartDrag,
  dayGeometry,
  children,
  manual,
}) => {
  const [isDragging, , enableDrag, disableDrag] = useToggle();

  const [startingGeometry, setStartingGeometry] = React.useState({ left: 0, width: 0 });
  const [workingEnd, setWorkingEnd] = React.useState<DateWithoutTime>(new DateWithoutTime());

  const [mouseDownX, setMouseDownX] = React.useState(0);

  const onMouseMove = (e: MouseEvent) => {
    const delta = e.clientX - mouseDownX;
    if (isDragging) {
      const newEnd = leftToDate(startingGeometry.left + delta, dayGeometry);
      if (!newEnd) return;
      setWorkingEnd(newEnd.date);
    }
    onChange &&
      workingEnd.getDaysSinceEpoch() !== endDate.getDaysSinceEpoch() &&
      onChange(null, workingEnd);
  };

  const startDrag = useCallback(
    (e: React.MouseEvent) => {
      enableDrag();
      setMouseDownX(e.clientX);
      setWorkingEnd(endDate);
      setStartingGeometry(barGeometry(dayGeometry, endDate, endDate));
      onStartDrag && onStartDrag();
    },
    [dayGeometry, enableDrag, endDate, onStartDrag],
  );

  const stopDrag = useCallback(
    (_e: React.MouseEvent | MouseEvent) => {
      disableDrag();
      onChange && onChange(null, workingEnd);
    },
    [disableDrag, onChange, workingEnd],
  );

  useDocumentMouseEvents(isDragging, undefined, stopDrag, onMouseMove);

  const geometry = isDragging
    ? barGeometry(dayGeometry, workingEnd, workingEnd)
    : barGeometry(dayGeometry, endDate, endDate);

  const barStyles = {
    left: geometry.left,
    width: geometry.width,
    top: 14,
  };

  const label = isDragging && (
    <div
      className="fixed bg-slate-500 rounded-md text-white p-1 font-mono"
      style={{
        top: 100,
        right: 10,
      }}
    >
      {dateWithoutTimeLabel(workingEnd)}
    </div>
  );

  const color = manual ? 'border-gray-600 border-2' : 'border-2 border-gray-300';

  return (
    <>
      {label}

      <div
        onMouseDown={startDrag}
        className={`rounded-full absolute ${color} h-3 flex flex-row justify-between p-0.5 cursor-move`}
        style={barStyles}
      >
        {children}
      </div>
    </>
  );
};
