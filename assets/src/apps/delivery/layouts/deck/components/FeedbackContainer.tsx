import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { selectIsLegacyTheme } from 'apps/delivery/store/features/page/slice';
import React from 'react';
import { useSelector } from 'react-redux';
import FeedbackRenderer from './FeedbackRenderer';

export interface FeedbackContainerProps {
  minimized: boolean;
  showIcon: boolean;
  showHeader: boolean;
  feedbacks: any[];
  onMinimize: () => void;
  onMaximize: () => void;
  style?: React.CSSProperties;
}

const FeedbackContainer: React.FC<FeedbackContainerProps> = ({
  minimized,
  showIcon,
  showHeader,
  feedbacks,
  onMinimize,
  onMaximize,
  style = {},
}) => {
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentActivityIds = (currentActivityTree || []).map((activity) => activity.id);

  const isLegacyTheme = useSelector(selectIsLegacyTheme);

  const handleToggleFeedback = () => {
    if (minimized) {
      onMaximize();
    } else {
      onMinimize();
    }
  };

  const handleCloseFeedback = () => {
    onMinimize();
  };

  return (
    <div
      className={`feedbackContainer rowRestriction ${isLegacyTheme ? 'columnRestriction' : ''}`}
      style={{ top: '525px', ...style }}
    >
      <div className={`bottomContainer fixed ${minimized ? 'minimized' : ''}`}>
        <button
          onClick={handleToggleFeedback}
          className={showIcon ? 'toggleFeedbackBtn' : 'toggleFeedbackBtn displayNone'}
          title="Toggle feedback visibility"
          aria-label="Show feedback"
          aria-haspopup="true"
          aria-controls="stage-feedback"
          aria-pressed="false"
        >
          <div className="icon" />
        </button>
        <div
          id="stage-feedback"
          className={minimized ? 'displayNone' : ''}
          role="alertdialog"
          aria-live="polite"
          aria-hidden="true"
          aria-label="Feedback dialog"
        >
          <div className={`theme-feedback-header ${showHeader ? '' : 'displayNone'}`}>
            <button
              onClick={handleCloseFeedback}
              className="theme-feedback-header__close-btn"
              aria-label="Minimize feedback"
            >
              <span>
                <div className="theme-feedback-header__close-icon" />
              </span>
            </button>
          </div>
          <style type="text/css" aria-hidden="true" />
          <style>
            {`
          #stage-feedback .content {
            overflow: hidden auto !important;
          }
        `}
          </style>
          <div className="content">
            <FeedbackRenderer
              feedbacks={feedbacks}
              snapshot={getLocalizedStateSnapshot(currentActivityIds)}
            />
          </div>
          {/* <button className="showSolnBtn showSolution displayNone">
                    <div className="ellipsis">Show solution</div>
                </button> */}
        </div>
      </div>
    </div>
  );
};

export default FeedbackContainer;
