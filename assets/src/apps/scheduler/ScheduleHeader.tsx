import React from 'react';
import { DayGeometry, weekGeometry } from './date-utils';

interface ScheduleHeaderRowProps {
  labels: boolean;
  dayGeometry: DayGeometry;
}

export const ScheduleHeaderRow: React.FC<ScheduleHeaderRowProps> = ({
  labels = false,
  dayGeometry,
}) => {
  const g = weekGeometry(dayGeometry);
  const totalWidth = g.reduce((sum, week) => sum + week.width, 0);

  return (
    <>
      <tr className="h-12 border-t-0 relative">
        <th className="w-[1px] p-[2px] border-r-0 border-l-0 bg-delivery-body dark:bg-delivery-body-dark sticky left-0 z-20 isolate relative">
          <div className="absolute -top-px left-0 right-0 h-px bg-delivery-body dark:bg-delivery-body-dark" />
        </th>
        <th className="w-48 font-bold text-[12px] bg-delivery-body dark:bg-delivery-body-dark sticky left-[1px] z-20 isolate relative">
          <div className="absolute -top-px left-0 right-0 h-px bg-delivery-body dark:bg-delivery-body-dark" />
        </th>
        <th
          className="p-0 relative bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800"
          style={{ minWidth: totalWidth }}
        >
          <ScheduleMonths dayGeometry={dayGeometry} />
        </th>
      </tr>
      <tr className="h-12 border-t-0">
        <th className="w-[1px] p-[2px] border-r-0 bg-white dark:bg-black border-l sticky left-0 z-20 isolate"></th>
        <th className="w-48 font-bold text-[12px] bg-white dark:bg-black sticky left-[1px] z-20 isolate">
          CONTENT
        </th>
        <th
          className="p-0 relative bg-white dark:bg-black border-t-0"
          style={{ minWidth: totalWidth }}
        >
          <ScheduleHeader labels={labels} dayGeometry={dayGeometry} />
        </th>
      </tr>
    </>
  );
};

interface ScheduleHeaderProps {
  labels: boolean;
  dayGeometry: DayGeometry;
}

interface ScheduleMonthsProps {
  dayGeometry: DayGeometry;
}

const monthNames = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

export const ScheduleHeader: React.FC<ScheduleHeaderProps> = ({ labels, dayGeometry }) => {
  const g = weekGeometry(dayGeometry);
  const totalWidth = g.reduce((sum, week) => sum + week.width, 0);

  return (
    <div className="absolute top-0 left-0 h-full" style={{ width: totalWidth }}>
      {g.map((g, i) => (
        <div
          role="week"
          key={i}
          className="p-0 align-top inline-block border-l h-full whitespace-nowrap text-ellipsis font-normal border-l-[#CED1D9] dark:border-gray-800 "
          style={{ width: g.width }}
        >
          {labels && (
            <>
              <div className="font-bold text-[11px]">{g.label}</div>
              <div className="text-[10px]">{g.dateLabel}</div>
            </>
          )}
        </div>
      ))}
    </div>
  );
};

export const ScheduleMonths: React.FC<ScheduleMonthsProps> = ({ dayGeometry }) => {
  const g = weekGeometry(dayGeometry);
  const gMonths = g.reduce((acc, g) => {
    const key = `${monthNames[g.month]}-${g.year}`;
    if (!acc.has(key)) {
      acc.set(key, 0);
    }
    const keyWidth = acc.get(key);
    acc.set(key, keyWidth + g.width);
    return acc;
  }, new Map());

  const totalWidth = g.reduce((sum, week) => sum + week.width, 0);

  return (
    <div className="absolute top-0 left-0 h-full" style={{ width: totalWidth }}>
      {Array.from(gMonths).map(([key, value], i) => (
        <div
          role="month"
          key={i}
          className="pb-2 align-top content-end inline-block border-l h-full whitespace-nowrap text-ellipsis font-normal border-l-[#CED1D9] dark:border-gray-800 "
          style={{ width: value }}
        >
          <div className="font-bold text-[11px]">{key.split('-')[0]}</div>
        </div>
      ))}
    </div>
  );
};
