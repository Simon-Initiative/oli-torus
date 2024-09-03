import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectIsLegacyTheme,
  selectPreviewMode,
  setAttemptType,
} from 'apps/delivery/store/features/page/slice';
import TimeAgo from '../../../../../components/common/TimeAgo';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import { setHistoryNavigationTriggered } from '../../../store/features/adaptivity/slice';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import { HistoryEntry } from './HistoryNavigation';

interface HistoryPanelProps {
  items: HistoryEntry[];
  onMinimize: any; // function?
  onRestart: any; // function
  oldAttemptTypeActivityIdIndex?: number;
  appAttemptType?: string;
}

const HistoryPanel: React.FC<HistoryPanelProps> = ({
  items,
  onMinimize,
  onRestart,
  oldAttemptTypeActivityIdIndex,
  appAttemptType,
}) => {
  const dispatch = useDispatch();
  const currentActivityId = useSelector(selectCurrentActivityId);
  // TODO: we need to track this as a separate ID
  const currentHistoryActiveActivityId = currentActivityId;

  const itemClickHandler = (item: HistoryEntry) => {
    dispatch(navigateToActivity(item.id));

    const nextHistoryActivityIndex = items.findIndex(
      (historyItem: any) => historyItem.id === item.id,
    );
    // if there is an ongoing lesson then there is a possibility that some of the activity data will be saved based on old approach and
    // some activity data will be stored based on new approach. To handle this, we added 2 session variables "session.old.attempt.resume" and  "session.attempType"
    // "session.old.attempt.resume" contains the id of the activity from where the new save approach was triggered. Hence, during history mode, when a student
    // visit an screen whose sequence index is less that the activity mentioned in the "session.old.attempt.resume" variable, we handle the
    // displaying of data in older way.
    if (
      nextHistoryActivityIndex - 1 > 0 &&
      appAttemptType == 'Mixed' &&
      oldAttemptTypeActivityIdIndex
    ) {
      if (nextHistoryActivityIndex - 1 >= oldAttemptTypeActivityIdIndex) {
        dispatch(setAttemptType({ attemptType: 'New' }));
      } else {
        dispatch(setAttemptType({ attemptType: appAttemptType }));
      }
    }
    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: nextHistoryActivityIndex !== 0,
      }),
    );
  };

  const getItemClasses = (item: HistoryEntry) => {
    const currentClass = 'history-element-current';
    const selectedClass = 'history-element-selected';
    const otherClass = 'history-element-other';
    const classes = ['history-element'];
    if (item.id === currentActivityId) {
      classes.push(currentClass);
    }
    if (item.id === currentHistoryActiveActivityId) {
      classes.push(selectedClass);
    }
    if (item.id !== currentActivityId && item.id !== currentHistoryActiveActivityId) {
      classes.push(otherClass);
    }
    return classes.join(' ');
  };

  const isLegacyTheme = useSelector(selectIsLegacyTheme);
  const isPreviewMode = useSelector(selectPreviewMode);
  return (
    <>
      {isLegacyTheme ? (
        <>
          <div className="navbar-resize-dots"></div>
          <div className="title screenListTitle">
            {isPreviewMode ? 'Screen List' : 'Lesson History'}
          </div>
          <nav className="history">
            {items.map((item, index) => (
              <div
                key={item.id}
                id={`qrID${item.id}`}
                className={getItemClasses(item)}
                onClick={() => itemClickHandler(item)}
              >
                {items.length - index}. {item.name}
              </div>
            ))}
          </nav>
        </>
      ) : (
        <div
          id="theme-history-panel"
          className="theme-history"
          aria-role="alertdialog"
          aria-hidden="false"
          aria-label="Lesson history"
        >
          <div className="theme-history__title">
            <span>Lesson History</span>
            <button
              onClick={onMinimize}
              className="theme-history__close-btn"
              aria-label="Minimize lesson history"
            >
              <span>
                <div className="theme-history__close-icon" />
              </span>
            </button>
          </div>
          <nav className="theme-history__nav">
            {items.map((item) => (
              <button
                key={item.id}
                className={getItemClasses(item)}
                onClick={() => itemClickHandler(item)}
              >
                <div className="history-element__screenName">{item.name}</div>
                <div className="history-element__timestamp">
                  {<TimeAgo timeStamp={item.timestamp as number} liveUpdate={true} />}
                </div>
              </button>
            ))}
          </nav>
          <div className="theme-history__footer">
            <button onClick={onRestart} className="theme-history__restart">
              <span>
                <div className="theme-history__restart-icon" />
                <span className="theme-history__restart-label">Restart Lesson</span>
              </span>
            </button>
          </div>
        </div>
      )}
    </>
  );
};

export default HistoryPanel;
