import React, { useCallback } from 'react';
import { useEffect, useState } from 'react';

interface TimeAgoProps {
  timeStamp: number;
  liveUpdate: boolean;
}

const MillisToDaysHoursMinutesAndSeconds = (millis: number) => {
  const minutes = Math.floor(millis / 60000);
  const hours = Math.floor((millis / (1000 * 60 * 60)) % 24);
  const days = Math.floor(millis / (1000 * 60 * 60 * 24));
  if (days > 0) {
    if (days === 1) {
      return 'a day ago';
    }
    return `${days}  days ago`;
  } else if (hours > 0) {
    if (hours === 1) {
      return 'an hour ago';
    }
    return `${hours} hours and ${minutes} minutes ago`;
  } else if (minutes > 0) {
    if (minutes === 1) {
      return 'a minute ago';
    }
    return `${minutes}  minutes ago`;
  } else {
    return 'a few seconds ago';
  }
};

const TimeAgo: React.FC<TimeAgoProps> = ({ timeStamp, liveUpdate }) => {
  const [time, setTime] = useState('');

  const tick = useCallback(() => {
    const currentDate = Date.now();
    const timeSince = currentDate - timeStamp;
    const timeTickerText = MillisToDaysHoursMinutesAndSeconds(timeSince);
    setTime(timeTickerText);
  }, [timeStamp]);

  useEffect(() => {
    if (timeStamp && liveUpdate) {
      const interval = setInterval(() => {
        tick();
      }, 1000);
      return () => clearInterval(interval);
    } else {
      tick();
    }
  }, [timeStamp, liveUpdate, tick]);

  if (!timeStamp) {
    return <span></span>;
  }

  return <span>{time}</span>;
};

export default TimeAgo;
