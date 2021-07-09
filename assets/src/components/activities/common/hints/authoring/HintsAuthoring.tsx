import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { ID } from 'data/content/model';
import { Hint, RichText } from 'components/activities/types';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { Card } from 'components/misc/Card';
import { Tooltip } from 'components/misc/Tooltip';
import { HintCard } from 'components/activities/common/hints/authoring/HintCard';

interface HintsAuthoringProps {
  addOne: () => void;
  updateOne: (id: ID, content: RichText) => void;
  removeOne: (id: ID) => void;
  deerInHeadlightsHint: Hint;
  cognitiveHints: Hint[];
  bottomOutHint: Hint;
}
export const HintsAuthoring: React.FC<HintsAuthoringProps> = ({
  deerInHeadlightsHint,
  cognitiveHints,
  bottomOutHint,
  addOne,
  updateOne,
  removeOne,
}) => {
  return (
    <>
      <DeerInHeadlightsHint hint={deerInHeadlightsHint} updateOne={updateOne} />
      <CognitiveHints
        hints={cognitiveHints}
        updateOne={updateOne}
        addOne={addOne}
        removeOne={removeOne}
      />
      <BottomOutHint hint={bottomOutHint} updateOne={updateOne} />
    </>
  );
};

interface HintProps {
  hint: Hint;
  updateOne: (id: ID, content: RichText) => void;
}
const DeerInHeadlightsHint: React.FC<HintProps> = ({ hint, updateOne }) => (
  <HintCard
    title={
      <>
        {'"Deer in headlights" hint'}
        <Tooltip title={'Restate the question for students who are totally confused'} />
      </>
    }
    placeholder="Restate the question"
    hint={hint}
    updateOne={updateOne}
  />
);

interface CognitiveProps {
  hints: Hint[];
  updateOne: (id: ID, content: RichText) => void;
  removeOne: (id: ID) => void;
  addOne: () => void;
}
const CognitiveHints: React.FC<CognitiveProps> = ({ hints, updateOne, removeOne, addOne }) => (
  <Card.Card>
    <Card.Title>
      {'"Cognitive" hints'}
      <Tooltip title={'Explain how to solve the problem'} />
    </Card.Title>
    <Card.Content>
      {hints.map((hint, index) => (
        <div key={hint.id} className="d-flex">
          <span className="mr-3 mt-2">{index + 1}.</span>
          <RichTextEditorConnected
            style={{ backgroundColor: 'white' }}
            placeholder="Explain how to solve the problem"
            className="mb-2 flex-grow-1"
            text={hint.content}
            onEdit={(content) => updateOne(hint.id, content)}
          />
          <div className="d-flex align-items-stretch">
            {index > 0 && <RemoveButtonConnected onClick={() => removeOne(hint.id)} />}
          </div>
        </div>
      ))}
      <AuthoringButtonConnected
        action={addOne}
        style={{ marginLeft: '22px' }}
        className="btn btn-sm btn-link"
      >
        Add cognitive hint
      </AuthoringButtonConnected>
    </Card.Content>
  </Card.Card>
);

const BottomOutHint: React.FC<HintProps> = ({ hint, updateOne }) => (
  <HintCard
    title={
      <>
        {'"Bottom out" hint'}
        <Tooltip title={'Explain the answer for students who are still lost'} />
      </>
    }
    placeholder="Explain the answer"
    hint={hint}
    updateOne={updateOne}
  />
);
