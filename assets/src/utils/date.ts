const monthsToOrdinal: any = {
  Jan: 0,
  Feb: 1,
  Mar: 2,
  Apr: 3,
  May: 4,
  Jun: 5,
  Jul: 6,
  Aug: 7,
  Sep: 8,
  Oct: 9,
  Nov: 10,
  Dec: 11,
};

function convertHour(hour: number, isPM: boolean): number {
  if (isPM) {
    return hour === 12 ? 12 : hour + 12;
  }

  return hour === 12 ? 0 : hour;
}

export function parseDate(value: string): Date {

  const p = value.split(' ');
  const t = p[3].split(':');

  return new Date(Date.UTC(
    parseInt(p[2], 10), monthsToOrdinal[p[0]],
    parseInt(p[1].substr(0, p[1].indexOf(',')), 10),
    convertHour(parseInt(t[0], 10), p[4] === 'PM'),
    parseInt(t[1], 10),
    parseInt(t[2], 10),
  ));
}

const dateOptions = {
  month: 'long', day: 'numeric', year: 'numeric', hour: 'numeric', minute: 'numeric',
};

export const dateFormatted = (date: Date): string =>
  date.toLocaleDateString('en-US', dateOptions);

export function compareDates(a: Date, b: Date) : number {
  return a.valueOf() - b.valueOf();
}

export function relativeToNow(a: Date) : string {
  return relativeTo(a, new Date());
}

// Take a date and return a new date taking into account
// some amount of time skew
export function adjustForSkew(a: Date, skewInMs: number) : Date {
  return new Date(a.getTime() + skewInMs);
}

/**
 * Returns a string indicating how long it is been from one date
 * to another, in the most reasonable unit.
 * @param dateFrom the date to compare against
 * @param dateNow the date to compare
 */
export function relativeTo(dateFrom: Date, dateNow: Date) : string {

  const delta = dateNow.getTime() - dateFrom.getTime();

  const MS_IN_SECOND = 1000;
  const MS_IN_MINUTE = 60 * MS_IN_SECOND;
  const MS_IN_HOUR = 60 * MS_IN_MINUTE;
  const MS_IN_DAY = 24 * MS_IN_HOUR;
  const MS_IN_WEEK = 7 * MS_IN_DAY;
  const MS_IN_MONTH = 30.5 * MS_IN_DAY;
  const MS_IN_YEAR = 365 * MS_IN_DAY;


  if (delta >= (MS_IN_YEAR * 2)) {
    return  Math.floor(delta / MS_IN_YEAR) + ' years ago';
  }
  if (delta >= (MS_IN_YEAR - MS_IN_MONTH)) {
    return 'a year ago';
  }
  if (delta >= (MS_IN_MONTH * 2)) {
    return Math.floor(delta / MS_IN_MONTH) + ' months ago';
  }
  if (delta >= (MS_IN_MONTH)) {
    return 'a month ago';
  }
  if (delta >= (MS_IN_WEEK * 2)) {
    return  Math.floor(delta / MS_IN_WEEK) + ' weeks ago';
  }
  if (delta >= MS_IN_WEEK - MS_IN_DAY) {
    return 'a week ago';
  }
  if (delta >= MS_IN_DAY * 2) {
    return Math.floor(delta / MS_IN_DAY) + ' days ago';
  }
  if (delta >= MS_IN_DAY) {
    return 'a day ago';
  }
  if (delta >= MS_IN_HOUR * 2) {
    return Math.floor(delta / MS_IN_HOUR) + ' hours ago';
  }
  if (delta >= MS_IN_HOUR) {
    return 'an hour ago';
  }
  if (delta >= MS_IN_MINUTE * 2) {
    return Math.floor(delta / MS_IN_MINUTE) + ' minutes ago';
  }
  if (delta >= MS_IN_MINUTE) {
    return 'a minute ago';
  }
  if (delta >= 7 * MS_IN_SECOND) {
    return Math.floor(delta / MS_IN_SECOND) + ' seconds ago';
  }
  if (delta >= 2 * MS_IN_SECOND) {
    return 'a few seconds ago';
  }

  return 'just now';
}
