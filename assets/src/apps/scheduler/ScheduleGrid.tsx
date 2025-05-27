import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import { useCallbackRef, useResizeObserver } from '@restart/hooks';
import { DateWithoutTime } from 'epoq';
import { modeIsDark } from 'components/misc/DarkModeSelector';
import { ClearIcon, CollapseAllIcon, ExpandAllIcon, SearchIcon } from 'components/misc/icons/Icons';
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

  const isScheduled = schedule.some((item: any) => {
    return item.startDateTime && item.endDateTime;
  });

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
      <div className="flex flex-row justify-between gap-x-4 mb-6 px-6 bg-[#F2F9FF] dark:bg-[#1F1D23]">
        <div>
          Start organizing your course with the interactive scheduling tool. Set dates for course
          content, and manage content by right-clicking to remove or re-add it. All scheduled items
          will appear in the student schedule and upcoming agenda.
        </div>
        <div className="flex flex-row gap-x-4 items-start py-1">
          {isScheduled ? (
            <button className="btn btn-sm btn-primary whitespace-nowrap" onClick={onReset}>
              <i className="fa fa-undo-alt" /> Reset Schedule
            </button>
          ) : (
            <button className="btn btn-sm btn-primary whitespace-nowrap" onClick={onReset}>
              <i className="fa fa-calendar" /> Set Schedule
            </button>
          )}
        </div>
      </div>
      <div className="flex flex-row gap-x-4 justify-start items-center w-auto h-[51px] mb-6 ml-[270px] mr-2 px-2 bg-white dark:bg-black shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)]">
        {/* Search Bar  */}
        <div className="relative w-[461px]">
          <SearchIcon className="text-[#383A44] dark:text-white absolute left-3 top-1/2 -translate-y-1/2" />

          <input
            className="w-[461px] h-9 pl-10 pr-3 dark:bg-[#2A282D] dark:text-[#eeebf5] rounded-md border border-[#CED1D9] dark:border-[#514C59] placeholder:text-[#bg-[var(--text-text-default,#353740)]]"
            type="text"
            placeholder="Search Schedule..."
          />
        </div>

        {/* Expand/Collapse All button */}
        <div className="flex flex-row items-center justify-start w-auto px-2 text-sm text-[#353740] ">
          <button id="expand_all_button" className="flex space-x-3 dark:text-[#eeebf5]">
            <ExpandAllIcon className="text-[#353740] dark:text-white ml-2" />
            <span>Expand All</span>
          </button>

          <button id="collapse_all_button" className="hidden space-x-3 dark:text-[#eeebf5]">
            <CollapseAllIcon className="text-[#353740] dark:text-white ml-2" />
            <span>Collapse All</span>
          </button>
        </div>

        {/* Clear Schedule button */}
        <button
          id="clear-schedule"
          className="btn btn-sm flex gap-1 items-center"
          onClick={onClear}
        >
          <ClearIcon className="text-[#0062F2] dark:text-white ml-2" />
          <span className="justify-start text-[#0062F2] text-sm font-bold dark:font-normal dark:text-[#eeebf5]">
            Clear
          </span>
        </button>
      </div>
      <div className="w-full px-4">
        <table className="select-none schedule_table border-t-0 border-l-0">
          <thead className="sticky top-14 z-10">
            <ScheduleHeaderRow
              labels={true}
              attachBarContainer={attachBarContainer}
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
                  modeIsDark()
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
