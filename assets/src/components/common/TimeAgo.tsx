import React from 'react';
import { useState, useEffect } from 'react';

interface TimeAgoProps {
  timeStamp: number;
  liveUpdate: boolean;
}
const TimeAgo: React.FC<TimeAgoProps> = ({ timeStamp, liveUpdate }) => {
  if (!timeStamp) {
    return <span></span>;
  }

  const [time, setTime] = useState('');
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
  const tick = () => {
    const currentDate = Date.now();
    const timeSince = currentDate - timeStamp;
    const timeTickerText = MillisToDaysHoursMinutesAndSeconds(timeSince);
    setTime(timeTickerText);
  };

  useEffect(() => {
    if (liveUpdate) {
      const interval = setInterval(() => {
        tick();
      }, 1000);
      return () => clearInterval(interval);
    } else {
      tick();
    }
  }, [timeStamp, liveUpdate]);
  return <span>{time}</span>;
};

export default TimeAgo;
