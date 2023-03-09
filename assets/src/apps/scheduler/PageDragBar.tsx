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
  hardSchedule: boolean;
}

export const PageDragBar: React.FC<DragBarProps> = ({
  endDate,
  onChange,
  onStartDrag,
  dayGeometry,
  hardSchedule,
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
    top: 7,
  };

  return (
    <div
      onMouseDown={startDrag}
      className={`absolute h-3 flex flex-row justify-between  cursor-move`}
      style={barStyles}
    >
      {hardSchedule ? (
        <span key="exclamation">
          <i className="fa fa-calendar "></i>
        </span>
      ) : (
        <span key="file">
          <i className="fa fa-file"></i>
        </span>
      )}
    </div>
  );
};
