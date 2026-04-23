/* eslint-disable react/prop-types */
import React, { Fragment } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { defaultGlobalEnv, getEnvState } from '../../../../../adaptivity/scripting';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import {
  setHistoryNavigationTriggered,
  setRestartLesson,
} from '../../../store/features/adaptivity/slice';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import { selectSequence } from '../../../store/features/groups/selectors/deck';
import {
  selectDebuggerURL,
  selectIsGraded,
  selectPreviewMode,
  selectShowHistory,
  setShowHistory,
} from '../../../store/features/page/slice';
import ReviewModeHistoryPanel from './ReviewModeHistoryPanel';

export interface ReviewEntry {
  id: string;
  name: string;
  timestamp?: number;
  current?: boolean;
  selected?: boolean;
}

const getSafeDebuggerURL = (value?: string): string | undefined => {
  if (!value) {
    return undefined;
  }

  return /^\/sections\/[^/]+\/debugger\/[^/]+$/.test(value) ? value : undefined;
};

const ReviewModeNavigation: React.FC = () => {
  const currentActivityId = useSelector(selectCurrentActivityId);
  const debuggerURL = useSelector(selectDebuggerURL);
  const safeDebuggerURL = getSafeDebuggerURL(debuggerURL);
  const graded = useSelector(selectIsGraded);
  const previewMode = useSelector(selectPreviewMode);
  const showHistory = useSelector(selectShowHistory);
  const sequences = useSelector(selectSequence);
  const dispatch = useDispatch();
  const canRestartLesson = !graded && !previewMode;

  const snapshot = getEnvState(defaultGlobalEnv);

  // Get the activities students visited
  const globalSnapshot = Object.keys(snapshot)
    .filter((key: string) => key.indexOf('session.visitTimestamps.') === 0)
    ?.reverse()
    .map((entry) => entry.split('.')[2]);

  const sortByTimestamp = (a: ReviewEntry, b: ReviewEntry) => {
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
  let historyItems: ReviewEntry[] = globalSnapshot
    ?.map((activityId) => {
      const foundSequence = sequences.filter(
        (sequence) => sequence.custom?.sequenceId === activityId,
      )[0];
      return {
        id: foundSequence.custom?.sequenceId,
        name: foundSequence.custom?.sequenceName || foundSequence.id,
        timestamp: snapshot[`session.visitTimestamps.${foundSequence.custom?.sequenceId}`],
      };
    })
    .sort(sortByTimestamp);
  historyItems = historyItems.reverse();

  const currentHistoryActivityIndex = historyItems.findIndex(
    (item: any) => item.id === currentActivityId,
  );
  const isFirst = currentHistoryActivityIndex === 0;
  const isLast = currentHistoryActivityIndex === historyItems.length - 1;

  const nextHandler = () => {
    const prevActivity = historyItems[currentHistoryActivityIndex + 1];
    dispatch(navigateToActivity(prevActivity.id));

    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: true,
      }),
    );
  };
  const minimizeHandler = () => {
    dispatch(setShowHistory({ show: !showHistory }));
  };
  const prevHandler = () => {
    const prevActivity = historyItems[currentHistoryActivityIndex - 1];
    dispatch(navigateToActivity(prevActivity.id));
    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: true,
      }),
    );
  };

  const handleToggleReviewModeScreenList = (show: boolean) => {
    dispatch(setShowHistory({ show }));
  };

  const restartHandler = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  return (
    <Fragment>
      {
        <div className="review-button">
          <style>
            {`
            .review-button {
              z-index: 1;
              display: flex;
              align-items: center;
              position: fixed;
              top: 0;
              left: calc(50% - .65rem);
            }
            .review-button .review-button-control {
              text-decoration: none;
              display: inline-flex;
              align-items: center;
              justify-content: center;
              width: 44px;
              height: 44px;
              padding: 4px 10px;
              font-size: 1.3rem;
              line-height: 1.5;
              border-radius: 0 0 4px 4px;
              border: 1px solid #6c757d;
              border-top: none;
              transition: color .15s ease-in-out, background-color .15s ease-in-out, box-shadow .15s ease-in-out;
              margin-right:15px;
              color: inherit;
              background-color: rgba(255, 255, 255, 0.867);
              box-sizing: border-box;
            }
            .review-button .review-button-control:hover {
              color: #fff;
              background-color: #6c757d;
              box-shadow: 0 1px 2px #00000079;
              cursor: pointer;
            }
            .review-button button.review-button-control:disabled {
              cursor: default;
            }
            .review-button .debugger-icon {
              width: 1.5rem;
              height: 1.5rem;
              fill: currentColor;
            }
            `}
          </style>
          <button
            className="review-button-control"
            onClick={() => handleToggleReviewModeScreenList(!showHistory)}
            title="Show lesson history"
            aria-label="Screen List"
          >
            <span title="Show lesson history" className="fa fa-list">
              &nbsp;
            </span>
          </button>
          {showHistory && (
            <div className={['navigationContainer', 'pullLeftInCheckContainer'].join(' ')}>
              {
                <ReviewModeHistoryPanel
                  items={historyItems}
                  onMinimize={minimizeHandler}
                ></ReviewModeHistoryPanel>
              }
            </div>
          )}
          <button
            className="review-button-control"
            onClick={prevHandler}
            title="Previous screen"
            aria-label="Previous screen"
            disabled={isFirst}
          >
            <span title="Previous screen" className="fa fa-arrow-left">
              &nbsp;
            </span>
          </button>
          <button
            className="review-button-control"
            onClick={nextHandler}
            title="Next screen"
            aria-label="Next screen"
            disabled={isLast}
          >
            <span title="Next screen" className="fa fa-arrow-right">
              &nbsp;
            </span>
          </button>
          {safeDebuggerURL && (
            <a
              className="review-button-control"
              href={safeDebuggerURL}
              target="_blank"
              rel="noopener noreferrer"
              title="Debugger"
              aria-label="Debugger"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 576 512"
                aria-hidden="true"
                className="debugger-icon"
              >
                <path d="M192 96c0-53 43-96 96-96s96 43 96 96l0 3.6c0 15.7-12.7 28.4-28.4 28.4l-135.1 0c-15.7 0-28.4-12.7-28.4-28.4l0-3.6zm345.6 12.8c10.6 14.1 7.7 34.2-6.4 44.8l-97.8 73.3c5.3 8.9 9.3 18.7 11.8 29.1l98.8 0c17.7 0 32 14.3 32 32s-14.3 32-32 32l-96 0 0 32c0 2.6-.1 5.3-.2 7.9l83.4 62.5c14.1 10.6 17 30.7 6.4 44.8s-30.7 17-44.8 6.4l-63.1-47.3c-23.2 44.2-66.5 76.2-117.7 83.9L312 280c0-13.3-10.7-24-24-24s-24 10.7-24 24l0 230.2c-51.2-7.7-94.5-39.7-117.7-83.9L83.2 473.6c-14.1 10.6-34.2 7.7-44.8-6.4s-7.7-34.2 6.4-44.8l83.4-62.5c-.1-2.6-.2-5.2-.2-7.9l0-32-96 0c-17.7 0-32 14.3-32 32s14.3 32 32 32l98.8 0c2.5-10.4 6.5-20.2 11.8-29.1L44.8 153.6c-14.1-10.6-17-30.7-6.4-44.8s30.7-17 44.8-6.4L192 184c12.3-5.1 25.8-8 40-8l112 0c14.2 0 27.7 2.8 40 8l108.8-81.6c14.1-10.6 34.2-7.7 44.8 6.4z" />
              </svg>
            </a>
          )}
          {canRestartLesson && (
            <button onClick={restartHandler} title="Restart lesson" aria-label="Restart lesson">
              <span title="Restart lesson" className="fa fa-repeat">
                &nbsp;
              </span>
            </button>
          )}
        </div>
      }
    </Fragment>
  );
};

export default ReviewModeNavigation;
