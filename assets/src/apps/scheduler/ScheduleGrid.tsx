import React, { useMemo } from 'react';
import { DateWithoutTime } from 'epoq';
import { generateDayGeometry } from './date-utils';
import { ScheduleHeaderRow } from './ScheduleHeader';
import { ScheduleLine } from './ScheduleLine';
import { useCallbackRef, useResizeObserver } from '@restart/hooks';
import { useSelector } from 'react-redux';
import { getTopLevelSchedule } from './schedule-selectors';
import { ScheduleItemType } from './scheduler-slice';

interface GridProps {
  startDate: string;
  endDate: string;
  onModification: () => void;
}
export const ScheduleGrid: React.FC<GridProps> = ({ startDate, endDate, onModification }) => {
  const [barContainer, attachBarContainer] = useCallbackRef<HTMLElement>();
  const rect = useResizeObserver(barContainer || null);

  const schedule = useSelector(getTopLevelSchedule);

  const dayGeometry = useMemo(
    () =>
      generateDayGeometry(
        new DateWithoutTime(startDate),
        new DateWithoutTime(endDate),
        rect?.width || 0,
      ),
    [rect?.width, startDate, endDate],
  );

  // Lets go ahead and say you need at least x pixels per day
  const minWidth = useMemo(() => {
    if (!dayGeometry) {
      return 300;
    }
    return (dayGeometry.end.getDaysSinceEpoch() - dayGeometry.start.getDaysSinceEpoch()) * 10;
  }, [dayGeometry]);

  return (
    <table className="select-none" style={{ minWidth }}>
      <thead>
        <ScheduleHeaderRow
          labels={true}
          attachBarContainer={attachBarContainer}
          dayGeometry={dayGeometry}
        />
      </thead>
      <tbody>
        {schedule
          .filter((item) => item.resource_type_id !== ScheduleItemType.Page)
          .map((item) => (
            <ScheduleLine
              onModification={onModification}
              key={item.id}
              indent={0}
              item={item}
              dayGeometry={dayGeometry}
            />
          ))}
      </tbody>
    </table>
  );
};
