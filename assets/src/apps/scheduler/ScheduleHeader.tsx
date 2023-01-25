import React from 'react';
import { DayGeometry, weekGeometry } from './date-utils';

interface ScheduleHeaderRowProps {
  labels: boolean;
  dayGeometry: DayGeometry;
  attachBarContainer?: (ref: any) => void;
}

export const ScheduleHeaderRow: React.FC<ScheduleHeaderRowProps> = ({
  labels = false,
  attachBarContainer,
  dayGeometry,
}) => {
  return (
    <tr className="h-8">
      <th className="w-1 border-r-0"></th>
      <th className="w-48"></th>
      <th className="p-0 relative" ref={attachBarContainer}>
        <ScheduleHeader labels={labels} dayGeometry={dayGeometry} />
      </th>
    </tr>
  );
};

interface ScheduleHeaderProps {
  labels: boolean;
  dayGeometry: DayGeometry;
}

export const ScheduleHeader: React.FC<ScheduleHeaderProps> = ({ labels, dayGeometry }) => {
  const g = weekGeometry(dayGeometry);
  return (
    <div className="absolute top-0 left-0 right-0 h-full">
      {g.map((g, i) => (
        <div
          key={i}
          className="p-0 align-top inline-block border-l h-full whitespace-nowrap text-ellipsis "
          style={{ width: g.width }}
        >
          {labels && g.width > 60 && g.label}
        </div>
      ))}
    </div>
  );
};
