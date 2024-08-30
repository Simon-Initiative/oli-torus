import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { setAttemptType, setShowHistory } from 'apps/delivery/store/features/page/slice';
import { selectCurrentActivityId } from '../../../store/features/activities/slice';
import { setHistoryNavigationTriggered } from '../../../store/features/adaptivity/slice';
import { navigateToActivity } from '../../../store/features/groups/actions/deck';
import { ReviewEntry } from './ReviewModeNavigation';

interface ReviewModeHistoryPanelProps {
  items: ReviewEntry[];
  onMinimize: any; // function?
  oldAttemptTypeActivityIdIndex?: number;
  appAttemptType?: string;
}

const ReviewModeHistoryPanel: React.FC<ReviewModeHistoryPanelProps> = ({
  items,
  oldAttemptTypeActivityIdIndex,
  appAttemptType,
}) => {
  const dispatch = useDispatch();
  const currentActivityId = useSelector(selectCurrentActivityId);
  // TODO: we need to track this as a separate ID
  const currentHistoryActiveActivityId = currentActivityId;

  const itemClickHandler = (item: ReviewEntry) => {
    const nextHistoryActivityIndex = items.findIndex(
      (historyItem: any) => historyItem.id === item.id,
    );
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
    dispatch(navigateToActivity(item.id));
    dispatch(
      setHistoryNavigationTriggered({
        historyModeNavigation: nextHistoryActivityIndex !== 0,
      }),
    );
  };

  const getItemClasses = (item: ReviewEntry) => {
    const currentClass = 'review-element-current';
    const selectedClass = 'review-element-selected';
    const otherClass = 'review-element-other';
    const classes = ['review-element'];
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
  const handleToggleHistory = (show: boolean) => {
    dispatch(setShowHistory({ show }));
  };
  return (
    <>
      {
        <>
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
            .review-button button {
              text-decoration: none;
              padding: 0 0 0 4px;
              font-size: 1.3rem;
              line-height: 1.5;
              border-radius: 0 0 4px 4px;
              border: 1px solid #6c757d;
              border-top: none;
              transition: color .15s ease-in-out, background-color .15s ease-in-out, box-shadow .15s ease-in-out;
              margin-right:15px;
            }
            .review-button button:hover {
              color: #fff;
              background-color: #6c757d;
              box-shadow: 0 1px 2px #00000079;
            }
            .navigationContainer .review {
              width: 100%;
              position: relative;
              color: rgba(255, 255, 255, 0.8);
              height: 100%;
              padding-top: 10px;
              overflow-y: auto;
              top: 0;
            }
            .navigationContainer .review-element {
              padding: 8px 20px !important;
              border: none !important;
              transition: all 250ms ease;
              cursor: pointer;
            }
            aside .review {
              right: 5px;
              left: 0;
              bottom: 0;
            }
            .navigationContainer .review-element-selected {
              background: none !important;
              color: #2e9fff;
             }
            `}
          </style>
          <div className="navbar-resize-dots"></div>
          <div className="title screenListTitle">
            Lesson History
            <a
              className="review-mode-panel-close-button"
              onClick={() => handleToggleHistory(false)}
              style={{ float: 'right', color: 'white', cursor: 'pointer' }}
            >
              <span className="fa fa-times">&nbsp;</span>
            </a>
          </div>
          <div
            className="review-mode-screen-list fixed top-0 w-72 text-black bg-white p-2 border-gray-500 border-2 max-h-[80vh] overflow-auto"
            style={{
              transform: 'translate(-50%, 110px)',
            }}
          >
            {items.map((item, index) => (
              <div
                key={item.id}
                id={`qrID${item.id}`}
                className={getItemClasses(item)}
                onClick={() => itemClickHandler(item)}
              >
                {index + 1}. {item.name}
              </div>
            ))}
          </div>
        </>
      }
    </>
  );
};

export default ReviewModeHistoryPanel;
