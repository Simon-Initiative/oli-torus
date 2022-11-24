import React from 'react';
import { useState, useEffect } from 'react';

interface TimeRemainingProps {
  remainingTimeInHours?: number;
  remainingTimeInMinutes?: number;
  remainingTimeInSeconds?: number;
  liveUpdate: boolean;
}

const TimeRemaining: React.FC<TimeRemainingProps> = ({
  remainingTimeInHours,
  remainingTimeInMinutes,
  remainingTimeInSeconds,
  liveUpdate,
}) => {
  const defaultHoursTimer = remainingTimeInHours ? remainingTimeInHours : '00';
  const defaultMinutesTimer = remainingTimeInMinutes ? remainingTimeInMinutes : '00';
  const defaultSecondsTimer = remainingTimeInSeconds ? remainingTimeInSeconds : '00';
  const [timer, setTimer] = useState(
    defaultHoursTimer + ':' + defaultMinutesTimer + ':' + defaultSecondsTimer,
  );

  const getTimeRemaining = (e: any) => {
    const total = Date.parse(e) - Date.parse(new Date().toString());
    const seconds = Math.floor((total / 1000) % 60);
    const minutes = Math.floor((total / 1000 / 60) % 60);
    const hours = Math.floor((total / 1000 / 60 / 60) % 24);
    return {
      total,
      hours,
      minutes,
      seconds,
    };
  };

  const startTimer = (e: any) => {
    const { total, hours, minutes, seconds } = getTimeRemaining(e);
    if (total >= 0) {
      setTimer(
        (hours > 9 ? hours : '0' + hours) +
          ':' +
          (minutes > 9 ? minutes : '0' + minutes) +
          ':' +
          (seconds > 9 ? seconds : '0' + seconds),
      );
    }
  };

  const clearTimer = (e: any) => {
    setInterval(() => {
      startTimer(e);
    }, 1000);
  };

  const getDeadTime = () => {
    const deadline = new Date();
    if (remainingTimeInMinutes) {
      deadline.setMinutes(deadline.getMinutes() + remainingTimeInMinutes);
    } else if (remainingTimeInHours) {
      deadline.setHours(deadline.getHours() + remainingTimeInHours);
    } else if (remainingTimeInSeconds) {
      deadline.setSeconds(deadline.getSeconds() + remainingTimeInSeconds);
    }
    return deadline;
  };

  useEffect(() => {
    if (liveUpdate) {
      clearTimer(getDeadTime());
    }
  }, []);

  if (!timer) {
    return <span></span>;
  }

  return <span>{timer}</span>;
};

export default TimeRemaining;
