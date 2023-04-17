import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { HasParts, makeHint } from 'components/activities/types';
import { Hints as HintUtils } from 'data/activities/model/hints';

interface Props {
  partId: string;
}
export const Hints: React.FC<Props> = (props) => {
  const { dispatch, model } = useAuthoringElementContext<HasParts>();
  return (
    <HintsAuthoring
      addOne={() => dispatch(HintUtils.addCognitiveHint(makeHint(''), props.partId))}
      updateOne={(id, content) => dispatch(HintUtils.setContent(id, content))}
      removeOne={(id) => dispatch(HintUtils.removeOne(id))}
      deerInHeadlightsHint={HintUtils.getDeerInHeadlightsHint(model, props.partId)}
      cognitiveHints={HintUtils.getCognitiveHints(model, props.partId)}
      bottomOutHint={HintUtils.getBottomOutHint(model, props.partId)}
    />
  );
};
