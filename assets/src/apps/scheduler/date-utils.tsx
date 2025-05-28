import React from 'react';
import { DateWithoutTime } from 'epoq';
import { padLeft } from '../../utils/common';

/*
  When translating a date to a position along our graphical schedule, there are several points that correlate to each date.
  Each coordinate should correspond to exactly one date.

  The first coordinate is the start of the schedule, the last coordinate is the end of the schedule.

  So if we have 10 days, and 100 pixels, each day is 10 pixels wide with day 0 being 0-9 and day 9 being 90-99

  Rarely will the math work out, so we're going to have fractional pixels to worry about. Whenever a boundary between
  dates occurs, the rounded pixel before that decimal is the day before and the rounded pixel after is the day after.

  So if we have 10 days, and 105 pixels, each day is 10.5 pixels wide with day 0 being 0-10, day 1 being 11-20 since the boundary was 10.5

  When we draw a bar, we have to draw it from the beginning to the end pixel, and not just blindly use a calculated width (so 11 pixels wide and
  10 pixels wide in the example above).  For very many, very small bars, this may become noticable.
*/

interface SingleDayGeometry {
  left: number;
  width: number;
  date: DateWithoutTime;
}

export interface DayGeometry {
  start: DateWithoutTime;
  end: DateWithoutTime;
  availableWidth: number;
  geometry: SingleDayGeometry[];
}

// Let's generate an array of geometry to use for our dates to use instead of doing it all on the fly every time.
// In the app, this will likely only really be re-calculated when the window is resized.
export const generateDayGeometry = (
  startDate: DateWithoutTime | null,
  endDate: DateWithoutTime | null,
  availableWidth: number,
): DayGeometry => {
  if (!startDate || !endDate) {
    return {
      start: new DateWithoutTime(0),
      end: new DateWithoutTime(0),
      availableWidth,
      geometry: [],
    };
  }
  const totalDays = endDate.getDaysSinceEpoch() - startDate.getDaysSinceEpoch() + 1;
  const geometry = [];
  for (let day = 0; day < totalDays; day++) {
    const left = Math.floor(((day / Math.max(1, totalDays)) * availableWidth) | 0);
    const next = Math.floor((((1 + day) / Math.max(1, totalDays)) * availableWidth) | 0);
    const date = new DateWithoutTime(startDate.getDaysSinceEpoch() + day);
    geometry.push({
      date,
      left: left,
      width: next - left,
    });
  }
  return {
    availableWidth,
    start: startDate,
    end: endDate,
    geometry,
  };
};

const findGeometry = (dayGeometry: DayGeometry, date: DateWithoutTime | null) => {
  if (!date) return null;

  const epoc = date.getDaysSinceEpoch();
  if (epoc < dayGeometry.start.getDaysSinceEpoch()) {
    // Requesting a date before our start date, gets you our start date
    return cloneOf(dayGeometry.geometry[0]);
  }

  if (epoc > dayGeometry.end.getDaysSinceEpoch()) {
    // Requesting a date after our start date, gets you our last date
    return cloneOf(dayGeometry.geometry[dayGeometry.geometry.length - 1]);
  }

  return cloneOf(dayGeometry.geometry.find((dg) => dg.date.getDaysSinceEpoch() === epoc));
};

/** Gets geometry between two dates
 * This differs from barGeometry, because it goes from the start of the first day to the start of the last day
 * instead of the start of the first day to the end of the last day.
 */
export const betweenGeometry = (
  dayGeometry: DayGeometry,
  startDate: DateWithoutTime | null,
  endDate: DateWithoutTime | null,
) => {
  if (!dayGeometry || !startDate) {
    return { width: 0, left: 0 };
  }

  const firstDate = new DateWithoutTime(
    Math.min(startDate.getDaysSinceEpoch(), (endDate || startDate).getDaysSinceEpoch()),
  );
  const lastDate = new DateWithoutTime(
    Math.max(startDate.getDaysSinceEpoch(), (endDate || startDate).getDaysSinceEpoch()),
  );

  const start = findGeometry(dayGeometry, firstDate);
  const end = findGeometry(dayGeometry, lastDate);
  const endPostion = end ? end.left : start ? start.left : 0;
  const left = start ? start.left : 0;
  const width = start ? endPostion - left : 0;

  return {
    width,
    left,
  };
};

export const barGeometry = (
  dayGeometry: DayGeometry,
  startDate: DateWithoutTime | null,
  endDate: DateWithoutTime | null,
) => {
  if (!dayGeometry || !startDate) {
    return { width: 0, left: 0 };
  }

  const firstDate = new DateWithoutTime(
    Math.min(startDate.getDaysSinceEpoch(), (endDate || startDate).getDaysSinceEpoch()),
  );
  const lastDate = new DateWithoutTime(
    Math.max(startDate.getDaysSinceEpoch(), (endDate || startDate).getDaysSinceEpoch()),
  );

  const start = findGeometry(dayGeometry, firstDate);
  const end = findGeometry(dayGeometry, lastDate);
  const endPostion = end ? end.left + end.width : start ? start.left + start.width : 0;
  const width = start ? endPostion - start.left : 0;

  return {
    width,
    left: start?.left || 0,
  };
};

const cloneOf = (orig: SingleDayGeometry | undefined): SingleDayGeometry | undefined => {
  if (!orig) return undefined;
  return {
    ...orig,
    date: new DateWithoutTime(orig.date.getDaysSinceEpoch()),
  };
};

// Turn a left offset of one of the bars to a date that corresponds.
export const leftToDate = (
  left: number,
  dayGeometry: DayGeometry,
): SingleDayGeometry | undefined => {
  if (!dayGeometry) {
    return undefined;
  }

  if (left < 0) return dayGeometry.geometry[0]; // Return the first one if we're before it

  return cloneOf(
    dayGeometry.geometry.find((dg) => dg.left <= left && dg.left + dg.width > left) ||
      dayGeometry.geometry[dayGeometry.geometry.length - 1], // return the last one if we're past it
  );
};

interface WeekGeometry {
  width: number;
  label: string;
  dateLabel: string;
  month: number;
  year: number;
}

const generateWeekLabel = (date: DateWithoutTime | null) => {
  if (!date) return '';
  const plus6 = new DateWithoutTime(date.getDaysSinceEpoch() + 6);
  return dateWithoutTimeShortLabel(date) + ' - ' + dateWithoutTimeShortLabel(plus6);
};

export const weekGeometry = (dayGeometry: DayGeometry): WeekGeometry[] => {
  // If there are:
  // < 30 weeks, show them all
  // < 50 weeks, show every other
  // < 70 weeks, every third
  // otherwise, none
  const weekCount = dayGeometry.geometry.length / 7;
  if (weekCount > 70) return [];
  const groupingCount = weekCount < 30 ? 7 : weekCount < 50 ? 14 : 21;

  return dayGeometry.geometry.reduce((acc, g, index) => {
    const last = acc[acc.length - 1];

    if (index % groupingCount === 0) {
      acc.push({
        width: g.width,
        label: `Wk ${Math.floor(index / 7) + 1}`,
        dateLabel: generateWeekLabel(g.date),
        month: g.date.getMonth(),
        year: g.date.getFullYear(),
      });
    } else {
      last.width += g.width;
    }

    return acc;
  }, [] as WeekGeometry[]);
};

export const dateTimeInTorusFormat = (d: Date | null) => {
  // Format that <input type="datetime-local"> requires: 2022-01-02T13:01
  if (!d) return null;
  return `${d.getFullYear()}-${padLeft(d.getMonth() + 1, 2)}-${padLeft(
    d.getDate(),
    2,
  )} ${d.getHours()}:${padLeft(d.getMinutes(), 2)}:${padLeft(d.getSeconds(), 2)}`;
};

export const dateWithTimeLabel = (d: Date | null) => {
  // Format that <input type="datetime-local"> requires: 2022-01-02T13:01
  if (!d) return null;
  return `${d.getFullYear()}-${padLeft(d.getMonth() + 1, 2)}-${padLeft(d.getDate(), 2)}T${padLeft(
    d.getHours(),
    2,
  )}:${padLeft(d.getMinutes(), 2)}`;
};

export const dateWithoutTimeLabel = (d: DateWithoutTime | null) => {
  if (!d) return null;
  return `${d.getFullYear()}-${padLeft(d.getMonth() + 1, 2)}-${padLeft(d.getDate(), 2)}`;
};

export const dateWithoutTimeShortLabel = (d: DateWithoutTime | null) => {
  if (!d) return null;
  return `${d.getMonth() + 1}/${d.getDate()}`;
};

export const dateWithoutTimeMonth = (d: DateWithoutTime | null) => {
  if (!d) return null;
  return d.getMonth();
};

/* Makes sure the start is before the end date. */
export const validateStartEndDates = (
  start: DateWithoutTime | null,
  end: DateWithoutTime | null,
) => {
  if (!start || !end) {
    return [start, end];
  }
  if (start.getDaysSinceEpoch() > end.getDaysSinceEpoch()) {
    return [end, start];
  }
  return [start, end];
};

export const DateWithoutTimeLabel: React.FC<{ date: DateWithoutTime }> = ({ date }) => {
  return <span>{dateWithoutTimeLabel(date)}</span>;
};

export const toDateWithoutTime = (date: Date | DateWithoutTime | null): DateWithoutTime | null => {
  if (!date) return null;
  if (date instanceof DateWithoutTime) return date;
  return new DateWithoutTime(date.getFullYear(), date.getMonth(), date.getDate());
};

export const stringToDateWithTime = (s: string): Date => {
  const parts = s.split('T');
  if (parts.length !== 2) throw new Error(`Invalid date string: ${s}`);
  const [date, time] = parts;
  const dateParts = date.split('-').map((s) => parseInt(s, 10));
  if (dateParts.length !== 3) throw new Error(`Invalid date string: ${s}`);
  const [year, month, day] = dateParts;
  const timeParts = time.split(':').map((s) => parseInt(s, 10));
  if (timeParts.length !== 2) throw new Error(`Invalid date string: ${s}`);
  const [hour, minute] = timeParts;
  return new Date(year, month - 1, day, hour, minute);
};

export const stringToDateWithoutTime = (s: string): DateWithoutTime => {
  const parts = s.split('-').map((s) => parseInt(s, 10));
  if (parts.length !== 3) throw new Error(`Invalid date string: ${s}`);
  const [year, month, day] = parts;

  return new DateWithoutTime(year, month - 1, day);
};
