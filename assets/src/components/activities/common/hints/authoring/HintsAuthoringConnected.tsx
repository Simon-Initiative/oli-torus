import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { HintsAuthoring as Component } from 'components/activities/common/hints/authoring/HintsAuthoring';
import {
  getBottomOutHint,
  getCognitiveHints,
  getDeerInHeadlightsHint,
} from 'components/activities/common/hints/authoring/hintUtils';
import { HasParts, makeHint } from 'components/activities/types';
import React from 'react';

interface Props {
  hintsPath: string;
}
export const Hints: React.FC<Props> = ({ hintsPath }) => {
  const { dispatch, model } = useAuthoringElementContext<HasParts>();
  return (
    <Component
      addOne={() => dispatch(HintActions.addHint(makeHint('')))}
      updateOne={(id, content) => dispatch(HintActions.editHint(id, content))}
      removeOne={(id) => dispatch(HintActions.removeHint(id, hintsPath))}
      deerInHeadlightsHint={getDeerInHeadlightsHint(model)}
      cognitiveHints={getCognitiveHints(model)}
      bottomOutHint={getBottomOutHint(model)}
    />
  );
};
