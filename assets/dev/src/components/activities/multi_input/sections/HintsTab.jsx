import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { partTitle } from 'components/activities/multi_input/utils';
import { makeHint } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';
import React from 'react';
export const HintsTab = (props) => {
    const { model, dispatch } = useAuthoringElementContext();
    return (<CognitiveHints key={props.input.id} hints={Hints.byPart(model, props.input.partId)} updateOne={(id, content) => dispatch(Hints.setContent(id, content))} addOne={() => dispatch(Hints.addOne(makeHint(''), props.input.partId))} removeOne={(id) => dispatch(Hints.removeOne(id))} placeholder="Hint" title={partTitle(props.input, props.index)}/>);
};
//# sourceMappingURL=HintsTab.jsx.map