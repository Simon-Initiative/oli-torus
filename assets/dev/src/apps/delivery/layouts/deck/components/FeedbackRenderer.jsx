var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import React, { Fragment, useCallback, useEffect, useState } from 'react';
import PartsLayoutRenderer from '../../../../../components/activities/adaptive/components/delivery/PartsLayoutRenderer';
const FeedbackRenderer = ({ feedbacks, snapshot = {} }) => {
    // use a key to force re-render when feedback array changes
    // feedback might be the same but needs to refresh
    const [renderId, setRenderId] = useState(Date.now());
    useEffect(() => {
        // console.log('FEEDBACK ARRAY CHANGED', { feedbacks, snapshot });
        setRenderId(Date.now());
    }, [feedbacks]);
    const handlePartInit = useCallback((partId) => __awaiter(void 0, void 0, void 0, function* () {
        // console.log('FEEDBACK part init', { partId, snapshot });
        return { snapshot };
    }), [snapshot]);
    return (<Fragment>
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
      {feedbacks.map((feedback) => (<div key={`${feedback.id}_${renderId}`} style={{
                width: feedback.custom.width,
                height: feedback.custom.height,
                backgroundColor: feedback.custom.palette.backgroundColor,
                borderWidth: feedback.custom.palette.borderWidth,
                borderColor: feedback.custom.palette.borderColor,
                borderStyle: feedback.custom.palette.borderStyle,
                borderRadius: feedback.custom.palette.borderRadius,
            }} className="feedback-item">
          <PartsLayoutRenderer parts={feedback.partsLayout} onPartInit={handlePartInit}/>
        </div>))}
    </Fragment>);
};
export default FeedbackRenderer;
//# sourceMappingURL=FeedbackRenderer.jsx.map