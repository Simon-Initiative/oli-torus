import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import TimeAgo from '../../../../../components/common/TimeAgo';
import { setHistoryNavigationTriggered } from '../../../store/features/adaptivity/slice';

interface HistoryEntry {
  id: string;
  name: string;
  timestamp?: any; // not sure if this is needed
  current?: boolean;
  selected?: boolean;
}

interface HistoryPanelProps {
  items: HistoryEntry[];
  onMinimize: any; // function?
  onRestart: any; // function
}

const HistoryPanel: React.FC<HistoryPanelProps> = ({ items, onMinimize, onRestart }) => {
  const dispatch = useDispatch();
  const currentActivityId = useSelector(selectCurrentActivityId);

  const itemClickHandler = (item: HistoryEntry) => {

    dispatch(navigateToActivity(item.id));
    dispatch(
      setHistoryNavigationTriggered({
        historyNavigationActivityId: item.id,
      }),
    );
  };

  const getItemClasses = (item: HistoryEntry) => {
    const currentClass = 'history-element-current';
    const selectedClass = 'history-element-selected';
    const classes = ['history-element'];
    // TODO: current is a feature of history of the actual current screen and not the history mode screen?
    if (item.id === currentActivityId) {
      classes.push(currentClass);
    }
    if (item.id === currentActivityId) {
      classes.push(selectedClass);
    }
    return classes.join(' ');
  };

  return (
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
              {<TimeAgo timeStamp={item.timestamp} liveUpdate={true} />}
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
  );
};

export default HistoryPanel;
