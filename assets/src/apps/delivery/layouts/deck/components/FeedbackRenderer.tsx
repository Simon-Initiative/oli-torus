import PartsLayoutRenderer from '../../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';
import React, { Fragment, useCallback, useEffect, useState } from 'react';

interface FeedbackRendererProps {
  feedbacks: any[];
  snapshot?: any;
}

const FeedbackRenderer: React.FC<FeedbackRendererProps> = ({ feedbacks, snapshot = {} }) => {
  // use a key to force re-render when feedback array changes
  // feedback might be the same but needs to refresh
  const [renderId, setRenderId] = useState<number>(Date.now());

  useEffect(() => {
    // console.log('FEEDBACK ARRAY CHANGED', { feedbacks, snapshot });
    setRenderId(Date.now());
  }, [feedbacks]);

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
      {feedbacks.map((feedback) => (
        <div
          key={`${feedback.id}_${renderId}`}
          style={{
            width: feedback.custom.width,
            height: feedback.custom.height,
            backgroundColor: feedback.custom.palette.backgroundColor,
            borderWidth: feedback.custom.palette.borderWidth,
            borderColor: feedback.custom.palette.borderColor,
            borderStyle: feedback.custom.palette.borderStyle,
            borderRadius: feedback.custom.palette.borderRadius,
          }}
          className="feedback-item"
        >
          <PartsLayoutRenderer parts={feedback.partsLayout} onPartInit={handlePartInit} />
        </div>
      ))}
    </Fragment>
  );
};

export default FeedbackRenderer;
