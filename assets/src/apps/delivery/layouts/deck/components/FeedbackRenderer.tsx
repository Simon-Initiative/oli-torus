/* eslint-disable react/prop-types */
import React from 'react';
import PartsLayoutRenderer from '../../../components/PartsLayoutRenderer';

interface FeedbackRendererProps {
  feedbacks: any[];
}

const FeedbackRenderer: React.FC<FeedbackRendererProps> = ({ feedbacks }) => {
  const combinedParts = feedbacks.reduce((collect: any[], feedback) => {
    collect.push(...feedback.partsLayout);
    return collect;
  }, []);
  // TODO: I don't think they need event handlers, but they *DO* need state
  return <PartsLayoutRenderer parts={combinedParts} />;
};

export default FeedbackRenderer;
