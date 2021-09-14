import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { partTitle } from 'components/activities/multi_input/utils';
import { makeHint } from 'components/activities/types';
import { getHints, hintsByPart } from 'data/activities/model/hintUtils';
import React from 'react';

interface Props {
  input: MultiInput;
  index: number;
}
export const HintsTab: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <CognitiveHints
      key={props.input.id}
      hints={getHints(model, props.input.partId)}
      updateOne={(id, content) => dispatch(HintActions.editHint(id, content, props.input.partId))}
      addOne={() => dispatch(HintActions.addHint(makeHint(''), props.input.partId))}
      removeOne={(id) =>
        dispatch(HintActions.removeHint(id, hintsByPart(props.input.partId), props.input.partId))
      }
      placeholder="Hint"
      title={partTitle(props.input, props.index)}
    />
  );
};
