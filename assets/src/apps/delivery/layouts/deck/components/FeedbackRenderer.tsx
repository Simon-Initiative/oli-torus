/* eslint-disable react/prop-types */
import React from 'react';
import PartsLayoutRenderer from '../../../components/PartsLayoutRenderer';

interface FeedbackRendererProps {
  feedbacks: any[];
  snapshot?: any;
}

const FeedbackRenderer: React.FC<FeedbackRendererProps> = ({ feedbacks, snapshot = {} }) => {
  const combinedParts = feedbacks.reduce((collect: any[], feedback) => {
    collect.push(...feedback.partsLayout);
    return collect;
  }, []);

  const handlePartInit = async (partId: string) => {
    /* console.log('FEEDBACK part init', partId); */
    return { snapshot };
  };

  // TODO: other handlers for parts, "advanced" things like tracking part responses within feedback??

  return (
    <div className="feedback-item" style={{overflow:'hidden auto', position:'relative'}}>
      <PartsLayoutRenderer parts={combinedParts} onPartInit={handlePartInit} />
    </div>
  );
};

export default FeedbackRenderer;
