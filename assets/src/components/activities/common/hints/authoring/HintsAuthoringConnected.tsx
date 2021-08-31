import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoring';
import {
  getBottomOutHint,
  getCognitiveHints,
  getDeerInHeadlightsHint,
} from 'data/activities/model/hintUtils';
import { HasParts, makeHint } from 'components/activities/types';
import React from 'react';

interface Props {
  hintsByPart: string;
  partId: string;
}
export const Hints: React.FC<Props> = ({ hintsByPart, partId }) => {
  const { dispatch, model } = useAuthoringElementContext<HasParts>();
  return (
    <HintsAuthoring
      addOne={() => dispatch(HintActions.addCognitiveHint(makeHint(''), partId))}
      updateOne={(id, content) => dispatch(HintActions.editHint(id, content, partId))}
      removeOne={(id) => dispatch(HintActions.removeHint(id, hintsByPart, partId))}
      deerInHeadlightsHint={getDeerInHeadlightsHint(model, partId)}
      cognitiveHints={getCognitiveHints(model, partId)}
      bottomOutHint={getBottomOutHint(model, partId)}
    />
  );
};
