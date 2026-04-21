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

const badgeStyles = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: '4px',
  fontSize: '11px',
  color: '#6b7280',
  marginBottom: '8px',
  padding: '2px 8px',
  backgroundColor: '#f3f4f6',
  borderRadius: '4px',
} as const;

const AIGeneratedBadge = () => (
  <div className="ai-generated-badge" style={badgeStyles}>
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
      {pending && feedbacks.length === 0 ? (
        <div
          key={`ai_feedback_pending_${renderId}`}
          id="feedback-content"
          className="feedback-item feedback-ai-generated feedback-ai-pending"
          tabIndex={2}
          role="status"
          aria-label="AI-generated feedback is loading"
          style={{ padding: '12px 16px' }}
        >
          <AIGeneratedBadge />
          <LoadingSpinner size={LoadingSpinnerSize.Small} align="left">
            Generating AI-generated feedback...
          </LoadingSpinner>
        </div>
      ) : null}
      {feedbacks.map((feedback, index) =>
        feedback.ai_generated ? (
          <div
            key={`ai_feedback_${renderId}_${index}`}
            id={index === 0 ? 'feedback-content' : undefined}
            className="feedback-item feedback-ai-generated"
            tabIndex={index === 0 ? 2 : undefined}
            role={index === 0 ? 'text' : undefined}
            aria-label="AI-generated feedback"
            style={{ padding: '12px 16px' }}
          >
            <AIGeneratedBadge />
            <p style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{feedback.text}</p>
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
            tabIndex={index === 0 ? 2 : undefined}
            role={index === 0 ? 'text' : undefined}
          >
            <PartsLayoutRenderer
              parts={feedback.partsLayout}
              onPartInit={handlePartInit}
              responsiveLayout={false}
            />
          </div>
        ),
      )}
    </Fragment>
  );
};

export default FeedbackRenderer;
