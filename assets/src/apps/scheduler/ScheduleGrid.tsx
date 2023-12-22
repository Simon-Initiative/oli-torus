import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import { useCallbackRef, useResizeObserver } from '@restart/hooks';
import { DateWithoutTime } from 'epoq';
import { ScheduleHeaderRow } from './ScheduleHeader';
import { ScheduleLine } from './ScheduleLine';
import { generateDayGeometry } from './date-utils';
import { getTopLevelSchedule } from './schedule-selectors';

interface GridProps {
  startDate: string;
  endDate: string;
  onReset: () => void;
  onClear: () => void;
}
export const ScheduleGrid: React.FC<GridProps> = ({ startDate, endDate, onReset, onClear }) => {
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
      <div className="flex flex-row justify-end gap-x-4 mb-6 px-6">
        <button className="btn btn-sm btn-primary" onClick={onReset}>
          Reset Timelines
        </button>
        <button id="clear-schedule" className="btn btn-sm btn-primary" onClick={onClear}>
          Clear Timelines
        </button>
      </div>

      <div className="w-full overflow-x-auto px-4">
        <table className="select-none table-striped border-t-0">
          <thead>
            <ScheduleHeaderRow
              labels={true}
              attachBarContainer={attachBarContainer}
              dayGeometry={dayGeometry}
            />
          </thead>
          <tbody>
            {schedule.map((item) => (
              <ScheduleLine key={item.id} indent={0} item={item} dayGeometry={dayGeometry} />
            ))}
          </tbody>
        </table>
        <Legend />
      </div>
    </div>
  );
};

const LegendIconItem: React.FC<{ icon: string; text: string; color: string }> = ({
  icon,
  text,
  color,
}) => (
  <span className="inline-flex items-center mr-4 rounded-md bg-gray-100 py-1 px-3">
    <i className={`fa fa-${icon} mr-3 ${color}`} />
    {text}
  </span>
);

const LegendBarItem: React.FC = () => (
  <span className="inline-flex items-center mr-4 rounded-md bg-gray-100 py-1 px-3">
    <span className="inline-block rounded bg-delivery-primary-300 dark:bg-delivery-primary-600 h-5 justify-between p-0.5 cursor-move w-10 mr-3" />
    Suggested Range
  </span>
);

const Legend = () => (
  <div className="flex flex-row align-middle mt-3 ">
    <span className="mr-3 my-auto">Legend:</span>
    <LegendBarItem />

    <LegendIconItem icon="flag" text="Available Date" color="text-green-500" />
    <LegendIconItem icon="file" text="Suggested Date" color="text-blue-500" />
    <LegendIconItem icon="users-line" text="In Class Activity" color="text-blue-500" />
    <LegendIconItem icon="calendar" text="Due Date" color="text-red-700" />
  </div>
);
