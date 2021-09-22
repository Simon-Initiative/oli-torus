import React, { useCallback, useEffect, useState } from 'react';
import PartsLayoutRenderer from '../../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';

interface FeedbackRendererProps {
  feedbacks: any[];
  snapshot?: any;
}

const FeedbackRenderer: React.FC<FeedbackRendererProps> = ({ feedbacks, snapshot = {} }) => {
  const [parts, setParts] = useState<any[]>([]);
  // use a key to force re-render when feedback array changes
  // feedback might be the same but needs to refresh
  const [renderId, setRenderId] = useState<number>(Date.now());

  useEffect(() => {
    // console.log('FEEDBACK ARRAY CHANGED', { feedbacks, snapshot });
    const combinedParts = feedbacks.reduce((collect: any[], feedback) => {
      collect.push(...feedback.partsLayout);
      return collect;
    }, []);
    setRenderId(Date.now());
    setParts(combinedParts);
  }, [feedbacks]);

  const handlePartInit = useCallback(
    async (partId: string) => {
      // console.log('FEEDBACK part init', { partId, snapshot });
      return { snapshot };
    },
    [snapshot],
  );

  // TODO: other handlers for parts, "advanced" things like tracking part responses within feedback??

  return (
    <div className="feedback-item" style={{ overflow: 'hidden auto' }}>
      <PartsLayoutRenderer key={renderId} parts={parts} onPartInit={handlePartInit} />
    </div>
  );
};

export default FeedbackRenderer;
