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
const darkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;

const rowPalette = [
  '#BC1A27',
  '#94849B',
  '#D97B68',
  '#973F7D',
  '#B9097E',
  '#737373',
  '#CC8100',
  '#869A13',
  '#2BA3AB',
  '#4F6831',
  '#0F7D85',
  '#58759D',
];

const rowPaletteDark = [
  '#FD7782',
  '#FCE7E3',
  '#E3D4E9',
  '#E58FCC',
  '#FF61CA',
  '#CFB5B5',
  '#FFC96B',
  '#E4FE4D',
  '#A1D463',
  '#82EBF2',
  '#AFC5E4',
  '#33F1FF',
];

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

  console.log('ScheduleGrid----dark mode', darkMode);
  return (
    <div className="pb-20">
      <div className="flex flex-row justify-between gap-x-4 mb-6 px-6">
        <div>
          Start organizing your course with the interactive scheduling tool. Set dates for course
          content, and manage content by right-clicking to remove or re-add it. All scheduled items
          will appear in the student schedule and upcoming agenda.
        </div>
        <div className="flex flex-row gap-x-4 items-start py-1">
          <button className="btn btn-sm btn-primary whitespace-nowrap" onClick={onReset}>
            <i className="fa fa-undo-alt" /> Reset Timelines
          </button>
          <button
            id="clear-schedule"
            className="btn btn-sm btn-primary whitespace-nowrap"
            onClick={onClear}
          >
            <i className="fa fa-trash-alt" /> Clear Timelines
          </button>
        </div>
      </div>

      <div className="w-full overflow-x-auto px-4">
        <table className="select-none table-striped border-t-0 border-l-0">
          <thead>
            <ScheduleHeaderRow
              labels={true}
              attachBarContainer={attachBarContainer}
              renderMonths={true}
              dayGeometry={dayGeometry}
            />
            <ScheduleHeaderRow
              labels={true}
              attachBarContainer={attachBarContainer}
              renderMonths={false}
              dayGeometry={dayGeometry}
            />
          </thead>
          <tbody>
            {schedule.map((item, index) => (
              <ScheduleLine
                key={item.id}
                index={index}
                indent={0}
                item={item}
                rowColor={
                  darkMode
                    ? rowPaletteDark[index % rowPaletteDark.length]
                    : rowPalette[index % rowPalette.length]
                }
                dayGeometry={dayGeometry}
              />
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
  <span className="inline-flex items-center mr-4 rounded-md bg-gray-100 py-1 px-3 dark:bg-black">
    <i className={`fa fa-${icon} mr-3 ${color}`} />
    {text}
  </span>
);

const LegendBarItem: React.FC = () => (
  <span className="inline-flex items-center mr-4 rounded-md bg-gray-100 py-1 px-3 dark:bg-black">
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
