import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { partTitle } from 'components/activities/multi_input/utils';
import { makeHint, RichText } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';
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
      hints={Hints.byPart(model, props.input.partId)}
      updateOne={(id, content) => dispatch(Hints.setContent(id, content as RichText))}
      addOne={() => dispatch(Hints.addOne(makeHint(''), props.input.partId))}
      removeOne={(id) => dispatch(Hints.removeOne(id))}
      placeholder="Hint"
      title={partTitle(props.input, props.index)}
    />
  );
};
