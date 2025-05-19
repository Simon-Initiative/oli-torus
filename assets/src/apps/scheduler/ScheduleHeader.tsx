import React from 'react';
import { DayGeometry, weekGeometry } from './date-utils';

interface ScheduleHeaderRowProps {
  labels: boolean;
  dayGeometry: DayGeometry;
  renderMonths: boolean;
  attachBarContainer?: (ref: any) => void;
}

export const ScheduleHeaderRow: React.FC<ScheduleHeaderRowProps> = ({
  labels = false,
  attachBarContainer,
  dayGeometry,
  renderMonths,
}) => {
  const content = renderMonths ? '' : 'CONTENT';
  return (
    <tr className="h-12 border-t-0 ">
      <th
        className={`w-[1px] p-[2px] border-r-0   ${
          renderMonths ? 'border-l-0' : 'bg-white dark:bg-black border-l'
        }`}
      ></th>
      <th className={`w-48 font-bold text-[12px] ${renderMonths ? '' : 'bg-white dark:bg-black'} `}>
        {content}
      </th>
      <th
        className={`p-0 relative bg-white dark:bg-black ${
          renderMonths ? 'border-t' : 'border-t-0'
        }`}
        ref={attachBarContainer}
      >
        <ScheduleHeader labels={labels} renderMonths={renderMonths} dayGeometry={dayGeometry} />
      </th>
    </tr>
  );
};

interface ScheduleHeaderProps {
  labels: boolean;
  renderMonths: boolean;
  dayGeometry: DayGeometry;
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

export const ScheduleHeader: React.FC<ScheduleHeaderProps> = ({
  labels,
  renderMonths,
  dayGeometry,
}) => {
  const g = weekGeometry(dayGeometry);
  const gMonths = g.reduce((acc, g) => {
    const key = monthNames[g.month];
    if (!acc.has(key)) {
      acc.set(key, 0);
    }
    const keyWidth = acc.get(key);
    acc.set(key, keyWidth + g.width);
    return acc;
  }, new Map());

  return (
    <div className="absolute top-0 left-0 right-0 h-full">
      {renderMonths &&
        Array.from(gMonths).map(([key, value], i) => (
          <div
            key={i}
            className="p-0 align-top inline-block border-l h-full whitespace-nowrap text-ellipsis font-normal dark:border-gray-800 "
            style={{ width: value }}
          >
            <div className="font-bold text-[11px]">{key}</div>
          </div>
        ))}

      {!renderMonths &&
        g.map((g, i) => (
          <div
            key={i}
            className="p-0 align-top inline-block border-l h-full whitespace-nowrap text-ellipsis font-normal dark:border-gray-800 "
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
