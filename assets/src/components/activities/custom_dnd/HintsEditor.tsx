import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { RichText, makeHint } from 'components/activities/types';
import { Hints } from 'data/activities/model/hints';

interface Props {
  partId: string;
}
export const HintsEditor: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<CustomDnDSchema>();

  return (
    <CognitiveHints
      key={props.partId}
      hints={Hints.byPart(model, props.partId)}
      updateOne={(id, content) => dispatch(Hints.setContent(id, content as RichText))}
      addOne={() => dispatch(Hints.addOne(makeHint(''), props.partId))}
      removeOne={(id) => dispatch(Hints.removeOne(id, props.partId))}
      placeholder="Hint"
      title={props.partId}
    />
  );
};
