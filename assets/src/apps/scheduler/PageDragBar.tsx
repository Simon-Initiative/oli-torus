import React, { useCallback, useState } from 'react';
import { DateWithoutTime } from 'epoq';
import { useDocumentMouseEvents } from '../../components/hooks/useDocumentMouseEvents';
import { useToggle } from '../../components/hooks/useToggle';
import {
  DayGeometry,
  barGeometry,
  betweenGeometry,
  leftToDate,
  validateStartEndDates,
} from './date-utils';
import { SchedulingType } from './scheduler-slice';

interface DragBarProps {
  endDate: DateWithoutTime | null;
  startDate: DateWithoutTime | null;
  isContainer: boolean;
  dayGeometry: DayGeometry;
  onChange?: (start: DateWithoutTime | null, end: DateWithoutTime | null) => void;
  onStartDrag?: () => void;
  manual: boolean;
  isSingleDay?: boolean;
  schedulingType: SchedulingType;
  isGraded: boolean;
}

export const DraggableIcon: React.FC<{
  date: DateWithoutTime;
  dayGeometry: DayGeometry;
  onChange: (date: DateWithoutTime) => void;
  onStartDrag?: () => void;
  children: React.ReactNode;
  offset: number;
}> = ({ date, dayGeometry, onChange, onStartDrag, children, offset }) => {
  const [isDragging, , enableDrag, disableDrag] = useToggle();

  const [startingGeometry, setStartingGeometry] = React.useState({ left: 0, width: 0 });

  const [mouseDownX, setMouseDownX] = React.useState(0);

  const [workingDate, setWorkingDate] = useState<DateWithoutTime>(new DateWithoutTime());

  const onMouseMove = (e: MouseEvent) => {
    const delta = e.clientX - mouseDownX;
    if (isDragging) {
      const newDate = leftToDate(startingGeometry.left + delta, dayGeometry);
      if (!newDate) return;
      setWorkingDate(newDate.date);
    }
    onChange &&
      workingDate.getDaysSinceEpoch() !== date.getDaysSinceEpoch() &&
      onChange(workingDate);
  };

  const startDrag = useCallback(
    (e: React.MouseEvent) => {
      enableDrag();
      setMouseDownX(e.clientX);
      setWorkingDate(date);
      setStartingGeometry(barGeometry(dayGeometry, date, date));
      onStartDrag && onStartDrag();
    },
    [enableDrag, date, dayGeometry, onStartDrag],
  );

  const stopDrag = useCallback(
    (e: React.MouseEvent | MouseEvent) => {
      disableDrag();
      onChange && onChange(workingDate);
    },
    [disableDrag, onChange, workingDate],
  );

  useDocumentMouseEvents(isDragging, undefined, stopDrag, onMouseMove);

  const geometry = isDragging
    ? barGeometry(dayGeometry, workingDate, workingDate)
    : barGeometry(dayGeometry, date, date);

  const barStyles = {
    left: geometry.left,
    width: geometry.width,
    top: 7,
    transform: `translate(0,${offset}px)`,
  };

  return (
    <div
      onMouseDown={startDrag}
      className="absolute h-3 flex flex-row justify-between cursor-move transition-transform"
      style={barStyles}
    >
      {children}
    </div>
  );
};

export const PageDragBar: React.FC<DragBarProps> = ({
  endDate,
  startDate,
  onChange,
  onStartDrag,
  dayGeometry,
  schedulingType,
  isGraded,
}) => {
  const onEndDateChange = useCallback(
    (date: DateWithoutTime) => {
      const [start, end] = validateStartEndDates(startDate, date);
      onChange && onChange(start, end);
    },
    [onChange, startDate],
  );

  const onStartDateChange = useCallback(
    (date: DateWithoutTime) => {
      const [start, end] = validateStartEndDates(date, endDate);
      onChange && onChange(start, end);
    },
    [onChange, endDate],
  );

  const hasStartEnd = isGraded && startDate && endDate;
  const geometry = betweenGeometry(dayGeometry, startDate, endDate);
  const offsetIcons = hasStartEnd && Math.abs(geometry.width) < 20;

  const showConnector = hasStartEnd && !offsetIcons;

  const EndIcon =
    schedulingType === 'due_by'
      ? DueDateIcon
      : schedulingType === 'inclass_activity'
      ? InClassIcon
      : SuggestedDateIcon;

  return (
    <>
      {showConnector && (
        <ConnectorLine dayGeometry={dayGeometry} startDate={startDate} endDate={endDate} />
      )}

      {endDate && (
        <DraggableIcon
          date={endDate}
          dayGeometry={dayGeometry}
          onStartDrag={onStartDrag}
          onChange={onEndDateChange}
          offset={offsetIcons ? 10 : 0}
        >
          <EndIcon />
        </DraggableIcon>
      )}

      {isGraded && startDate && (
        <DraggableIcon
          date={startDate}
          dayGeometry={dayGeometry}
          onStartDrag={onStartDrag}
          onChange={onStartDateChange}
          offset={offsetIcons ? -10 : 0}
        >
          <AvailableDateIcon />
        </DraggableIcon>
      )}
    </>
  );
};

const ConnectorLine: React.FC<{
  dayGeometry: DayGeometry;
  startDate: DateWithoutTime;
  endDate: DateWithoutTime;
}> = ({ dayGeometry, startDate, endDate }) => {
  const geometry = betweenGeometry(dayGeometry, startDate, endDate);

  const barStyle = {
    left: geometry.left,
    width: geometry.width,
    top: 17,
  };

  return <span className="absolute rounded-sm bg-blue-500 h-1" style={barStyle} />;
};

export const InClassIcon: React.FC = () => (
  <span key="inclass">
    <i className="fa fa-users-line text-blue-500"></i>
  </span>
);

export const AvailableDateIcon: React.FC = () => (
  <span key="flag">
    <i className="fa fa-flag text-green-500"></i>
  </span>
);

export const SuggestedDateIcon: React.FC = () => (
  <span key="file">
    <i className="fa fa-file text-blue-500"></i>
  </span>
);

export const DueDateIcon: React.FC = () => (
  <span key="exclamation">
    <i className="fa fa-calendar text-red-700"></i>
  </span>
);
