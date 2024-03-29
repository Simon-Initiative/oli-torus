import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { partTitle } from 'components/activities/multi_input/utils';
import { RichText, makeHint } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';

interface Props {
  input: MultiInput;
  index: number;
}
export const HintsTab: React.FC<Props> = (props) => {
  const { model, dispatch, projectSlug } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <CognitiveHints
      projectSlug={projectSlug}
      key={props.input.id}
      hints={Hints.byPart(model, props.input.partId)}
      updateOne={(id, content) => dispatch(Hints.setContent(id, content as RichText))}
      updateOneEditor={(id, editor) => dispatch(Hints.setEditor(id, editor))}
      updateOneTextDirection={(id, textDirection) =>
        dispatch(Hints.setTextDirection(id, textDirection))
      }
      addOne={() => dispatch(Hints.addOne(makeHint(''), props.input.partId))}
      removeOne={(id) => dispatch(Hints.removeOne(id, props.input.partId))}
      placeholder="Hint"
      title={partTitle(props.input, props.index)}
    />
  );
};
