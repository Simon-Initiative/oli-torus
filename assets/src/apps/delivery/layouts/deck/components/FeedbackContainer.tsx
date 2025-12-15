import React, { useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { selectCurrentActivityTree } from 'apps/delivery/store/features/groups/selectors/deck';
import { selectIsLegacyTheme } from 'apps/delivery/store/features/page/slice';
import FeedbackRenderer from './FeedbackRenderer';

export interface FeedbackContainerProps {
  minimized: boolean;
  showIcon: boolean;
  showHeader: boolean;
  feedbacks: any[];
  onMinimize: () => void;
  onMaximize: () => void;
  style?: React.CSSProperties;
  onFocusReturn?: () => void;
}

const FeedbackContainer: React.FC<FeedbackContainerProps> = ({
  minimized,
  showIcon,
  showHeader,
  feedbacks,
  onMinimize,
  onMaximize,
  style = {},
  onFocusReturn,
}) => {
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const currentActivityIds = (currentActivityTree || []).map((activity) => activity.id);

  const isLegacyTheme = useSelector(selectIsLegacyTheme);
  const [renderId, setRenderId] = useState<number>(Date.now());
  const feedbackContentRef = useRef<HTMLDivElement>(null);
  const previousMinimizedRef = useRef<boolean>(minimized);
  const previousFeedbacksLengthRef = useRef<number>(feedbacks.length);
  const hasAnnouncedRef = useRef<boolean>(false);

  const handleToggleFeedback = () => {
    if (minimized) {
      onMaximize();
    } else {
      // Close feedback - return focus immediately to prevent extra announcements
      onMinimize();
      if (onFocusReturn) {
        // Use requestAnimationFrame to ensure DOM updates complete first
        requestAnimationFrame(() => {
          setTimeout(() => {
            onFocusReturn();
          }, 100);
        });
      }
    }
  };
  useEffect(() => {
    // Only update renderId when feedbacks actually change, not on every render
    if (feedbacks.length > 0) {
      setRenderId(Date.now());
    }
  }, [feedbacks]);

  // Focus feedback content when it appears
  useEffect(() => {
    const feedbackJustAppeared =
      !minimized &&
      feedbacks.length > 0 &&
      (previousMinimizedRef.current !== minimized || previousFeedbacksLengthRef.current === 0);

    if (feedbackJustAppeared) {
      // Reset announcement flag for new feedback
      hasAnnouncedRef.current = false;
      // Feedback just appeared - focus the feedback content
      setTimeout(() => {
        const feedbackElement = document.getElementById('feedback-content');
        if (feedbackElement) {
          feedbackElement.focus();
        }
        // Mark as announced after a short delay to prevent re-announcements
        setTimeout(() => {
          hasAnnouncedRef.current = true;
        }, 500);
      }, 100);
    }

    // Return focus when feedback is minimized (closed)
    const feedbackJustClosed =
      minimized &&
      previousMinimizedRef.current !== minimized &&
      previousMinimizedRef.current === false;

    if (feedbackJustClosed) {
      hasAnnouncedRef.current = false;
      if (onFocusReturn) {
        // Use requestAnimationFrame to ensure DOM updates complete first
        requestAnimationFrame(() => {
          setTimeout(() => {
            onFocusReturn();
          }, 100);
        });
      }
    }

    previousMinimizedRef.current = minimized;
    previousFeedbacksLengthRef.current = feedbacks.length;
  }, [minimized, feedbacks.length, onFocusReturn]);

  const handleCloseFeedback = () => {
    // Close feedback - return focus immediately to prevent extra announcements
    onMinimize();
    if (onFocusReturn) {
      // Use requestAnimationFrame to ensure DOM updates complete first
      requestAnimationFrame(() => {
        setTimeout(() => {
          onFocusReturn();
        }, 100);
      });
    }
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
          aria-label={minimized ? 'Show feedback' : 'Close feedback'}
          tabIndex={1}
        >
          <div className="icon" />
        </button>
        <div
          id="stage-feedback"
          className={minimized ? 'displayNone' : ''}
          aria-live={hasAnnouncedRef.current ? 'off' : 'assertive'}
          aria-atomic="false"
        >
          <div className={`theme-feedback-header ${showHeader ? '' : 'displayNone'}`}>
            <button
              onClick={handleCloseFeedback}
              className="theme-feedback-header__close-btn"
              aria-label="Close feedback"
              tabIndex={3}
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
          <div className="content" ref={feedbackContentRef}>
            <FeedbackRenderer
              key={`${renderId}`}
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
