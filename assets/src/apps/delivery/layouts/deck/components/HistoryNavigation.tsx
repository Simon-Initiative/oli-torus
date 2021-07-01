/* eslint-disable react/prop-types */
import { setRestartLesson } from '../../../store/features/adaptivity/slice';
import React, { Fragment, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import HistoryPanel from './HistoryPanel';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import { selectEnableHistory } from '../../../store/features/page/slice';
import { defaultGlobalEnv, getEnvState } from '../../../../../adaptivity/scripting';
import {
  navigateToActivity,
  navigateToNextActivity,
  navigateToPrevActivity,
} from '../../../store/features/groups/actions/deck';
import { selectSequence } from '../../../store/features/groups/selectors/deck';

const HistoryNavigation: React.FC = () => {
  const currentActivityId = useSelector(selectCurrentActivityId);
  const isHistoryModeOn = true; //useSelector(selectEnableHistory);
  const [minimized, setMinimized] = useState(true);
  const sequences = useSelector(selectSequence);
  const dispatch = useDispatch();

  const restartHandler = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  const minimizeHandler = () => {
    setMinimized(!minimized);
  };

  // TODO this is actually driven by the student's history IF you are a student
  //and the toc otherwise

  const snapshot = getEnvState(defaultGlobalEnv);
  console.log({ snapshot });

  const globalSnapshot = Object.keys(snapshot)
    .filter((key: string) => key.indexOf('visitTimestamp') !== -1)
    ?.map((entry) => entry.split('|')[0]);

  const historyItems =
    sequences
      ?.filter((sequence) => globalSnapshot.includes(sequence.custom?.sequenceId))
      .map((entry: any) => {
        return {
          id: entry.custom?.sequenceId,
          name: entry.custom?.sequenceName || entry.id,
        };
      }) || [];

  const currentEnsembleIndex = historyItems.findIndex((item: any) => item.id === currentActivityId);
  const isFirst = currentEnsembleIndex === 0;
  const isLast = currentEnsembleIndex === historyItems.length - 1;
  const nextHandler = () => {
    const prevActivity = historyItems[currentEnsembleIndex + 1];
    dispatch(navigateToActivity(prevActivity.id));
  };

  const prevHandler = () => {
    const prevActivity = historyItems[currentEnsembleIndex - 1];
    dispatch(navigateToActivity(prevActivity.id));
  };
  return (
    <Fragment>
      {isHistoryModeOn ? (
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
          isHistoryModeOn ? undefined : 'pullLeftInCheckContainer',
        ].join(' ')}
      >
        <aside className={minimized ? 'minimized' : undefined}>
          {isHistoryModeOn ? (
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
          ) : null}
          <button onClick={restartHandler} className="theme-no-history-restart">
            <span>
              <div className="theme-no-history-restart__icon" />
              <span className="theme-no-history-restart__label">Restart Lesson</span>
            </span>
          </button>
        </aside>
      </div>
    </Fragment>
  );
};

export default HistoryNavigation;
