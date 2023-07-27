import React, { useEffect } from 'react';
import { useSelector } from 'react-redux';
import { useToggle } from 'components/hooks/useToggle';
import { selectPreviewMode } from 'apps/delivery/store/features/page/slice';
import LessonDeadlineDialog from './LessonDeadlineDialog';

const MIN_TIME_TO_DISPLAY_SECONDS = 60 * 60; // Only display if less than an hour remaining

export const DeadlineTimer: React.FC<{
  deadline: number;
  lateSubmit: 'allow' | 'disallow';
  overviewURL: string;
}> = ({ deadline, lateSubmit, overviewURL }) => {
  const isPreviewMode = useSelector(selectPreviewMode);
  const [remainingSeconds, setRemainingSeconds] = React.useState(Number.MAX_SAFE_INTEGER);
  const [tooltipOpen, , openTooltip, closeTooltip] = useToggle(false);
  const [timerOpen, toggleTimer] = useToggle(true);
  const [latePopupOpen, , showLatePopup, hideLatePopup] = useToggle(false);

  useEffect(() => {
    const remaining = Math.floor((deadline - Date.now()) / 1000);
    if (remaining <= 0 || isPreviewMode) {
      // If the deadline has already passed, don't bother setting up the timer
      return;
    }

    const timer = setInterval(() => {
      const newRemaining = Math.floor((deadline - Date.now()) / 1000);
      setRemainingSeconds(newRemaining);
      if (newRemaining <= 0) {
        clearInterval(timer);
        showLatePopup();
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [deadline, isPreviewMode]);

  if (isPreviewMode) return null;

  if (latePopupOpen) {
    return (
      <LessonDeadlineDialog
        lateSubmit={lateSubmit}
        onClose={hideLatePopup}
        overviewURL={overviewURL}
      />
    );
  }

  if (remainingSeconds > MIN_TIME_TO_DISPLAY_SECONDS) return null;
  if (remainingSeconds <= 0) return null;

  const minutes = Math.floor(remainingSeconds / 60);
  const seconds = Math.floor(remainingSeconds % 60);
  const collapsedWidthClass = 'w-12';
  const expandedWidthClass = 'w-48';
  const widthClass = tooltipOpen ? expandedWidthClass : collapsedWidthClass;
  const commonClassName =
    'cursor-pointer box-content text-sm fixed text-center top-12 right-2 z-[2000] bg-body text-body-900 deadline-timer border-[#d9d9de] border-[1px] transition-[width]';
  const timerClassName = `overflow-hidden p-2 ${widthClass} ${commonClassName}`;
  const collapsedClassName = `overflow-hidden p-1 w-3 ${commonClassName}`;
  const className = timerOpen ? timerClassName : collapsedClassName;
  return (
    <div
      id="deadline-timer"
      onMouseEnter={openTooltip}
      onMouseLeave={closeTooltip}
      className={className}
      onClick={toggleTimer}
    >
      {timerOpen && (
        <div className="whitespace-nowrap">
          {tooltipOpen && <span>Submission Deadline:&nbsp;</span>}
          {minutes}:{seconds < 10 ? `0${seconds}` : seconds}
        </div>
      )}

      {timerOpen || (
        <>
          <i aria-label="Deadline Clock" className="fa fa-clock" />
        </>
      )}
    </div>
  );
};
