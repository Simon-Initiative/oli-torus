import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { HintCard } from 'components/activities/common/hints/authoring/HintCard';
import { Hint, RichText } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';
import React from 'react';
import { Descendant } from 'slate';

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
    title={<>{'"Deer in headlights" hint'}</>}
    placeholder="Restate the question for students who are confused by the prompt"
    hint={hint}
    updateOne={updateOne}
  />
);

interface CognitiveProps {
  hints: Hint[];
  updateOne: (id: ID, content: Descendant[]) => void;
  removeOne: (id: ID) => void;
  addOne: () => void;
  title?: React.ReactNode;
  placeholder?: string;
}
export const CognitiveHints: React.FC<CognitiveProps> = ({
  hints,
  updateOne,
  removeOne,
  addOne,
  title,
  placeholder,
}) => (
  <Card.Card>
    <Card.Title>{title || '"Cognitive" hints'}</Card.Title>
    <Card.Content>
      {hints.map((hint, index) => (
        <div key={hint.id} className="d-flex">
          <div className="mr-3 mt-2" style={{ flexBasis: '18px' }}>
            {index + 1}.
          </div>
          <RichTextEditorConnected
            placeholder={placeholder || 'Explain how to solve the problem'}
            className="mb-2 flex-grow-1"
            value={hint.content}
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
        Add hint
      </AuthoringButtonConnected>
    </Card.Content>
  </Card.Card>
);

const BottomOutHint: React.FC<HintProps> = ({ hint, updateOne }) => (
  <HintCard
    title={<>{'"Bottom out" hint'}</>}
    placeholder="Explain the answer for students who are still confused"
    hint={hint}
    updateOne={updateOne}
  />
);
