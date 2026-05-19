import React, { Fragment, useCallback, useEffect, useState } from 'react';
import PartsLayoutRenderer from '../../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';

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

const AIThinkingSpinner = () => (
  <svg
    viewBox="0 0 30 30"
    className="feedback-ai-thinking-spinner"
    aria-hidden="true"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect
      className="feedback-ai-spinner-segment s0"
      x="12.8789"
      y="10.0503"
      width="4"
      height="10"
      rx="2"
      transform="rotate(135 12.8789 10.0503)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s1"
      x="10"
      y="13"
      width="4"
      height="10"
      rx="2"
      transform="rotate(90 10 13)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s2"
      x="10.0508"
      y="17.1213"
      width="4"
      height="10"
      rx="2"
      transform="rotate(45 10.0508 17.1213)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s3"
      x="13"
      y="20"
      width="4"
      height="10"
      rx="2"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s4"
      x="27.0234"
      y="24.1924"
      width="4"
      height="10"
      rx="2"
      transform="rotate(135 27.0234 24.1924)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s5"
      x="30"
      y="13"
      width="4"
      height="10"
      rx="2"
      transform="rotate(90 30 13)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s6"
      x="24.1953"
      y="2.97925"
      width="4"
      height="10"
      rx="2"
      transform="rotate(45 24.1953 2.97925)"
      fill="currentColor"
    />
    <rect
      className="feedback-ai-spinner-segment s7"
      x="13"
      width="4"
      height="10"
      rx="2"
      fill="currentColor"
    />
  </svg>
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
          .feedback-ai-pending {
            align-items: flex-start;
            display: flex !important;
            flex-direction: column;
            gap: 14px;
          }
          .feedback-ai-generated__loading {
            align-items: center;
            display: inline-flex;
            gap: 8px;
            line-height: 1.4;
          }
          .feedback-ai-thinking-spinner {
            color: currentColor;
            flex: 0 0 auto;
            height: 22px;
            width: 22px;
          }
          .feedback-ai-spinner-segment {
            animation: feedback-ai-spinner-segment-fade 1.2s linear infinite;
            opacity: 0.15;
          }
          .feedback-ai-spinner-segment.s0 {
            animation-delay: 0s;
          }
          .feedback-ai-spinner-segment.s1 {
            animation-delay: -0.15s;
          }
          .feedback-ai-spinner-segment.s2 {
            animation-delay: -0.3s;
          }
          .feedback-ai-spinner-segment.s3 {
            animation-delay: -0.45s;
          }
          .feedback-ai-spinner-segment.s4 {
            animation-delay: -0.6s;
          }
          .feedback-ai-spinner-segment.s5 {
            animation-delay: -0.75s;
          }
          .feedback-ai-spinner-segment.s6 {
            animation-delay: -0.9s;
          }
          .feedback-ai-spinner-segment.s7 {
            animation-delay: -1.05s;
          }
          @keyframes feedback-ai-spinner-segment-fade {
            0% {
              opacity: 1;
            }
            12.5% {
              opacity: 0.87;
            }
            25% {
              opacity: 0.75;
            }
            37.5% {
              opacity: 0.63;
            }
            50% {
              opacity: 0.51;
            }
            62.5% {
              opacity: 0.39;
            }
            75% {
              opacity: 0.27;
            }
            87.5% {
              opacity: 0.15;
            }
            100% {
              opacity: 0.15;
            }
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
          <div className="feedback-ai-generated__loading">
            <AIThinkingSpinner />
            <span>Thinking...</span>
          </div>
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
