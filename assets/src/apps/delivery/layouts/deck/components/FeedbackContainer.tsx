import { getLocalizedCurrentStateSnapshot } from 'apps/delivery/store/features/adaptivity/actions/getLocalizedCurrentStateSnapshot';
import React from 'react';
import { useDispatch } from 'react-redux';
import FeedbackRenderer from './FeedbackRenderer';

export interface FeedbackContainerProps {
  minimized: boolean;
  showIcon: boolean;
  showHeader: boolean;
  feedbacks: any[];
  onMinimize: () => void;
  onMaximize: () => void;
}

const FeedbackContainer: React.FC<FeedbackContainerProps> = ({
  minimized,
  showIcon,
  showHeader,
  feedbacks,
  onMinimize,
  onMaximize,
}) => {
  const [currentLocalizedSnapshot, setCurrentLocalizedSnapshot] = React.useState<any>({});

  const dispatch = useDispatch();

  const updateSnapshot = React.useCallback(async () => {
    const sResult = await dispatch(getLocalizedCurrentStateSnapshot());
    const {
      payload: { snapshot },
    } = sResult as any;

    setCurrentLocalizedSnapshot(snapshot);
  }, []);

  React.useEffect(() => {
    updateSnapshot();
  }, [feedbacks]);

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
    <div className="feedbackContainer rowRestriction" style={{ top: 525 }}>
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
          <div className="content" style={{ overflow: 'hidden auto !important' }}>
            {/* TODO: snapshot method causes constant re-render (props change) */}
            <FeedbackRenderer feedbacks={feedbacks} snapshot={currentLocalizedSnapshot} />
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
