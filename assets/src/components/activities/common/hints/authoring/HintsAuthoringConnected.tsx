import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoring';
import {
  getBottomOutHint,
  getCognitiveHints,
  getDeerInHeadlightsHint,
} from 'components/activities/common/hints/authoring/hintUtils';
import { makeHint } from 'components/activities/types';
import React from 'react';

interface Props {
  hintsPath: string;
}
export const HintsAuthoringConnected: React.FC<Props> = ({ hintsPath }) => {
  const { dispatch, model } = useAuthoringElementContext();
  return (
    <HintsAuthoring
      addOne={() => dispatch(HintActions.addHint(makeHint('')))}
      updateOne={(id, content) => dispatch(HintActions.editHint(id, content))}
      removeOne={(id) => dispatch(HintActions.removeHint(id, hintsPath))}
      deerInHeadlightsHint={getDeerInHeadlightsHint(model)}
      cognitiveHints={getCognitiveHints(model)}
      bottomOutHint={getBottomOutHint(model)}
    />
  );
};
