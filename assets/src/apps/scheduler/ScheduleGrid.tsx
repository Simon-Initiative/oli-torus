import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import { useCallbackRef, useResizeObserver } from '@restart/hooks';
import { DateWithoutTime } from 'epoq';
import { ScheduleHeaderRow } from './ScheduleHeader';
import { ScheduleLine } from './ScheduleLine';
import { generateDayGeometry } from './date-utils';
import { getTopLevelSchedule } from './schedule-selectors';
import { ScheduleItemType } from './scheduler-slice';

interface GridProps {
  startDate: string;
  endDate: string;
  onReset: () => void;
}
export const ScheduleGrid: React.FC<GridProps> = ({ startDate, endDate, onReset }) => {
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

  return (
    <div className="pb-20">
      <div className="flex container justify-end">
        <button className=" text-delivery-primary uppercase underline" onClick={onReset}>
          Reset Timelines
        </button>
      </div>

      <div className="w-full overflow-x-auto">
        <table className="select-none table-striped border-t-0">
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
                <ScheduleLine key={item.id} indent={0} item={item} dayGeometry={dayGeometry} />
              ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
