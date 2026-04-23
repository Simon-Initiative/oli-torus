import React, { Fragment, useCallback, useEffect, useState } from 'react';
import PartsLayoutRenderer from '../../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import {
  LoadingSpinner,
  LoadingSpinnerSize,
} from '../../../../../components/common/LoadingSpinner';

interface FeedbackRendererProps {
  feedbacks: any[];
  pending?: boolean;
  snapshot?: any;
}

const AIGeneratedBadge = () => (
  <div className="feedback-ai-generated__badge">
    <i className="fa fa-robot" aria-hidden="true" />
    <span>AI-generated</span>
  </div>
);

const FeedbackRenderer: React.FC<FeedbackRendererProps> = ({
  feedbacks,
  pending = false,
  snapshot = {},
}) => {
  // use a key to force re-render when feedback array changes
  // feedback might be the same but needs to refresh
  const [renderId, setRenderId] = useState<number>(Date.now());

  useEffect(() => {
    // console.log('FEEDBACK ARRAY CHANGED', { feedbacks, snapshot });
    setRenderId(Date.now());
  }, [feedbacks, pending]);

  const handlePartInit = useCallback(
    async (partId: string) => {
      // console.log('FEEDBACK part init', { partId, snapshot });
      return { snapshot };
    },
    [snapshot],
  );

  return (
    <Fragment>
      <style>
        {`
          .feedback-item > * {
            position: static !important;
          }
          .feedback-item janus-text-flow {
            width: auto !important;
          }
        `}
      </style>
      {pending ? (
        <div
          key={`ai_feedback_pending_${renderId}`}
          id="feedback-content"
          className="feedback-item feedback-ai-generated feedback-ai-pending"
          tabIndex={-1}
          role="status"
        >
          <AIGeneratedBadge />
          <LoadingSpinner size={LoadingSpinnerSize.Small} align="left">
            Generating AI-generated feedback...
          </LoadingSpinner>
        </div>
      ) : (
        feedbacks.map((feedback, index) =>
          feedback.system_error ? (
            <div
              key={`feedback_error_${renderId}_${index}`}
              id={index === 0 ? 'feedback-content' : undefined}
              className="feedback-item feedback-system-message"
              tabIndex={index === 0 ? -1 : undefined}
              role={index === 0 ? 'alert' : undefined}
            >
              <p className="feedback-system-message__text">{feedback.text}</p>
            </div>
          ) : feedback.ai_generated ? (
            <div
              key={`ai_feedback_${renderId}_${index}`}
              id={index === 0 ? 'feedback-content' : undefined}
              className="feedback-item feedback-ai-generated"
              tabIndex={index === 0 ? -1 : undefined}
              role={index === 0 ? 'text' : undefined}
              aria-label="AI-generated feedback"
            >
              <AIGeneratedBadge />
              <p className="feedback-ai-generated__text">{feedback.text}</p>
            </div>
          ) : (
            <div
              key={`${feedback.id}_${renderId}`}
              id={index === 0 ? 'feedback-content' : undefined}
              style={{
                width: feedback.custom?.width,
                height: feedback.custom?.height,
                backgroundColor: feedback.custom?.palette?.backgroundColor,
                borderWidth: feedback.custom?.palette?.borderWidth,
                borderColor: feedback.custom?.palette?.borderColor,
                borderStyle: feedback.custom?.palette?.borderStyle,
                borderRadius: feedback.custom?.palette?.borderRadius,
              }}
              className="feedback-item"
              tabIndex={index === 0 ? -1 : undefined}
              role={index === 0 ? 'text' : undefined}
            >
              <PartsLayoutRenderer
                parts={feedback.partsLayout}
                onPartInit={handlePartInit}
                responsiveLayout={false}
              />
            </div>
          ),
        )
      )}
    </Fragment>
  );
};

export default FeedbackRenderer;
