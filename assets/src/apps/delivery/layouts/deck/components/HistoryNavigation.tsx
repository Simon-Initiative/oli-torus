/* eslint-disable react/prop-types */
import React, { Fragment, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { defaultGlobalEnv, getEnvState } from '../../../../../adaptivity/scripting';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import {
  selectHistoryNavigationActivity,
  setHistoryNavigationTriggered,
  setRestartLesson,
} from '../../../store/features/adaptivity/slice';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import { selectSequence } from '../../../store/features/groups/selectors/deck';
import {
  selectEnableHistory,
  selectShowHistory,
  setAttemptType,
  setShowHistory,
} from '../../../store/features/page/slice';
import HistoryPanel from './HistoryPanel';

export interface HistoryEntry {
  id: string;
  name: string;
  timestamp?: number;
  current?: boolean;
  selected?: boolean;
}

const HistoryNavigation: React.FC = () => {
  const currentActivityId = useSelector(selectCurrentActivityId);
  const enableHistory = useSelector(selectEnableHistory);
  const showHistory = useSelector(selectShowHistory);
  const isHistoryMode = useSelector(selectHistoryNavigationActivity);
  let oldAttemptTypeActivityIdIndex = -1;
  let attemptType = '';
  const sequences = useSelector(selectSequence);
  const dispatch = useDispatch();

  const restartHandler = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  const minimizeHandler = () => {
    dispatch(setShowHistory({ show: !showHistory }));
  };

  const snapshot = getEnvState(defaultGlobalEnv);

  // Get the activities student visited
  const globalSnapshot = Object.keys(snapshot)
    .filter((key: string) => key.indexOf('session.visitTimestamps.') === 0)
    ?.reverse()
    .map((entry) => entry.split('.')[2]);

  const sortByTimestamp = (a: HistoryEntry, b: HistoryEntry) => {
    if (a.timestamp !== undefined && b.timestamp !== undefined) {
      if (a.timestamp == 0) {
        return b.timestamp - Date.now();
      } else if (b.timestamp == 0) {
        return Date.now() - b.timestamp;
      }
      return b.timestamp - a.timestamp;
    }
    return 0;
  };

  // Get the activity names and ids to be displayed in the history panel
  const historyItems: HistoryEntry[] = globalSnapshot
    ?.map((activityId) => {
      const foundSequence = sequences.filter(
        (sequence) => sequence.custom?.sequenceId === activityId,
      )[0];
      return {
        id: foundSequence.custom?.sequenceId,
        name: foundSequence.custom?.sequenceName || String(foundSequence.resourceId),
        timestamp: snapshot[`session.visitTimestamps.${foundSequence.custom?.sequenceId}`],
      };
    })
    .sort(sortByTimestamp);

  const currentHistoryActivityIndex = historyItems.findIndex(
    (item: any) => item.id === currentActivityId,
  );
  const isFirst = currentHistoryActivityIndex === historyItems.length - 1;
  const isLast = currentHistoryActivityIndex === 0;

  useEffect(() => {
    // if there is an ongoing lesson then there is a possibility that some of the activity data will be saved based on old approach and
    // some activity data will be stored based on new approach. To handle this, we added 2 session variables "session.old.attempt.resume" and  "session.attempType"
    // "session.old.attempt.resume" contains the id of the activity from where the new save approach was triggered. Hence, during history mode, when a student
    // visit an screen whose sequence index is less that the activity mentioned in the "session.old.attempt.resume" variable, we handle the
    // displaying of data in older way.
    const oldAttemptResumeActivityId = snapshot['session.old.attempt.resume'];
    const appAttemptType = snapshot['session.attempType'];
    const oldAttemptActivityIdIndex = historyItems.findIndex(
      (item: any) => item.id === oldAttemptResumeActivityId,
    );
    attemptType = appAttemptType;
    oldAttemptTypeActivityIdIndex = oldAttemptActivityIdIndex;
    if (currentHistoryActivityIndex > 0 && appAttemptType == 'Mixed') {
      if (currentHistoryActivityIndex >= oldAttemptActivityIdIndex) {
        dispatch(setAttemptType({ attemptType: 'New' }));
        attemptType = 'New';
      } else {
        dispatch(setAttemptType({ attemptType: appAttemptType }));
      }
    }
  }, [currentHistoryActivityIndex]);

  /*  console.log('HISTORY ITEMS', {
    historyItems,
    globalSnapshot,
    currentActivityId,
    isFirst,
    isLast,
    isHistoryMode,
    currentHistoryActivityIndex,
  }); */

  const nextHandler = () => {
    const prevActivity = historyItems[currentHistoryActivityIndex - 1];
    dispatch(navigateToActivity(prevActivity.id));

    const nextHistoryActivityIndex = historyItems.findIndex(
      (item: any) => item.id === prevActivity.id,
    );
    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: nextHistoryActivityIndex !== 0,
      }),
    );
  };

  const prevHandler = () => {
    const prevActivity = historyItems[currentHistoryActivityIndex + 1];
    dispatch(navigateToActivity(prevActivity.id));
    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: true,
      }),
    );
  };

  return (
    <Fragment>
      {enableHistory ? (
        <div className="historyStepView pullLeftInCheckContainer">
          <div className="historyStepContainer">
            <button
              onClick={prevHandler}
              className="backBtn historyStepButton"
              aria-label="Previous screen"
              disabled={isFirst}
            >
              <span className="icon-chevron-left" />
            </button>
            <button
              onClick={nextHandler}
              className="nextBtn historyStepButton"
              aria-label="Next screen"
              disabled={isLast || !isHistoryMode}
            >
              <span className="icon-chevron-right" />
            </button>
          </div>
        </div>
      ) : null}
      <div
        className={[
          'navigationContainer',
          enableHistory ? undefined : 'pullLeftInCheckContainer',
        ].join(' ')}
      >
        <aside className={`ui-resizable ${showHistory ? undefined : 'minimized'}`}>
          {enableHistory ? (
            <Fragment>
              <button
                onClick={minimizeHandler}
                className="navigationToggle"
                aria-label="Show lesson history"
                aria-haspopup="true"
                aria-controls="theme-history-panel"
                aria-pressed="false"
              />

              <HistoryPanel
                items={historyItems}
                onMinimize={minimizeHandler}
                onRestart={restartHandler}
                oldAttemptTypeActivityIdIndex={oldAttemptTypeActivityIdIndex}
                appAttemptType={attemptType}
              />
            </Fragment>
          ) : (
            <button onClick={restartHandler} className="theme-no-history-restart">
              <span>
                <div className="theme-no-history-restart__icon" />
                <span className="theme-no-history-restart__label">Restart Lesson</span>
              </span>
            </button>
          )}
        </aside>
      </div>
    </Fragment>
  );
};

export default HistoryNavigation;
