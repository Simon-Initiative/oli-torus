/* eslint-disable react/prop-types */
import { setRestartLesson } from '../../../store/features/adaptivity/slice';
import React, { Fragment, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import HistoryPanel from './HistoryPanel';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import { selectEnableHistory } from '../../../store/features/page/slice';
import { defaultGlobalEnv, getEnvState } from '../../../../../adaptivity/scripting';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import { selectSequence } from '../../../store/features/groups/selectors/deck';
import { setHistoryNavigationTriggered } from '../../../store/features/adaptivity/slice';

const HistoryNavigation: React.FC = () => {
  const currentActivityId = useSelector(selectCurrentActivityId);
  const enableHistory = useSelector(selectEnableHistory);

  const [minimized, setMinimized] = useState(true);
  const sequences = useSelector(selectSequence);
  const dispatch = useDispatch();

  const restartHandler = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  const minimizeHandler = () => {
    setMinimized(!minimized);
  };

  const snapshot = getEnvState(defaultGlobalEnv);

  // Get the activities student visited
  const globalSnapshot = Object.keys(snapshot)
    .filter((key: string) => key.indexOf('session.visitTimestamps.') === 0)
    ?.reverse()
    .map((entry) => entry.split('.')[2]);

  // Get the activity names and ids to be displayed in the history panel
  const historyItems = globalSnapshot?.map((activityId) => {
    const foundSequence = sequences.filter(
      (sequence) => sequence.custom?.sequenceId === activityId,
    )[0];
    return {
      id: foundSequence.custom?.sequenceId,
      name: foundSequence.custom?.sequenceName || foundSequence.id,
      timestamp: snapshot[`session.visitTimestamps.${foundSequence.custom?.sequenceId}`],
    };
  });
  const currentHistoryActivityIndex = historyItems.findIndex(
    (item: any) => item.id === currentActivityId,
  );
  const isFirst = currentHistoryActivityIndex === historyItems.length - 1;
  const isLast = currentHistoryActivityIndex === 0;
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
              disabled={isLast}
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
        <aside className={minimized ? 'minimized' : undefined}>
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
