import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { makeHint } from 'components/activities/types';
import { Hints as HintUtils } from 'data/activities/model/hints';
import React from 'react';
export const Hints = (props) => {
    const { dispatch, model } = useAuthoringElementContext();
    return (<HintsAuthoring addOne={() => dispatch(HintUtils.addCognitiveHint(makeHint(''), props.partId))} updateOne={(id, content) => dispatch(HintUtils.setContent(id, content))} removeOne={(id) => dispatch(HintUtils.removeOne(id))} deerInHeadlightsHint={HintUtils.getDeerInHeadlightsHint(model, props.partId)} cognitiveHints={HintUtils.getCognitiveHints(model, props.partId)} bottomOutHint={HintUtils.getBottomOutHint(model, props.partId)}/>);
};
//# sourceMappingURL=HintsAuthoringConnected.jsx.map