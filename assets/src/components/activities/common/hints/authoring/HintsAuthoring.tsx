import React from 'react';
import { Descendant } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { HintCard } from 'components/activities/common/hints/authoring/HintCard';
import { Hint, RichText } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';
import { DEFAULT_EDITOR, EditorType, SMALL_EDITOR_HEIGHT } from 'data/content/resource';

interface HintsAuthoringProps {
  addOne: () => void;
  updateOne: (id: ID, content: RichText) => void;
  updateOneEditor: (id: ID, editor: EditorType) => void;
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
  updateOneEditor,
}) => {
  const { projectSlug } = useAuthoringElementContext();
  return (
    <>
      <DeerInHeadlightsHint
        hint={deerInHeadlightsHint}
        updateOne={updateOne}
        updateOneEditor={updateOneEditor}
        projectSlug={projectSlug}
      />
      <CognitiveHints
        hints={cognitiveHints}
        updateOne={updateOne}
        addOne={addOne}
        removeOne={removeOne}
        updateOneEditor={updateOneEditor}
        projectSlug={projectSlug}
      />
      <BottomOutHint
        hint={bottomOutHint}
        updateOne={updateOne}
        updateOneEditor={updateOneEditor}
        projectSlug={projectSlug}
      />
    </>
  );
};

interface HintProps {
  hint: Hint;
  projectSlug: string;
  updateOne: (id: ID, content: RichText) => void;
  updateOneEditor: (id: ID, editor: EditorType) => void;
}
const DeerInHeadlightsHint: React.FC<HintProps> = ({
  hint,
  updateOne,
  updateOneEditor,
  projectSlug,
}) => (
  <HintCard
    title={<>{'"Deer in headlights" hint'}</>}
    placeholder="Restate the question for students who are confused by the prompt"
    hint={hint}
    updateOne={updateOne}
    updateOneEditor={updateOneEditor}
    projectSlug={projectSlug}
  />
);

interface CognitiveProps {
  hints: Hint[];
  updateOne: (id: ID, content: Descendant[]) => void;
  updateOneEditor: (id: ID, editor: EditorType) => void;
  removeOne: (id: ID) => void;
  addOne: () => void;
  title?: React.ReactNode;
  placeholder?: string;
  projectSlug: string;
}
export const CognitiveHints: React.FC<CognitiveProps> = ({
  hints,
  updateOne,
  removeOne,
  addOne,
  title,
  placeholder,
  projectSlug,
  updateOneEditor,
}) => (
  <Card.Card>
    <Card.Title>{title || '"Cognitive" hints'}</Card.Title>
    <Card.Content>
      {hints.map((hint, index) => (
        <div key={hint.id} className="d-flex mb-2">
          <div className="py-2 mr-3 w-[20px]">{index + 1}.</div>
          <SlateOrMarkdownEditor
            initialHeight={SMALL_EDITOR_HEIGHT}
            placeholder={placeholder || 'Explain how to solve the problem'}
            className="flex-grow-1"
            content={hint.content}
            onEdit={(content) => updateOne(hint.id, content)}
            onEditorTypeChange={(editor) => updateOneEditor(hint.id, editor)}
            editMode={true}
            editorType={hint.editor || DEFAULT_EDITOR}
            allowBlockElements={true}
            projectSlug={projectSlug}
          />
          <div className="d-flex align-items-stretch">
            {index > 0 && <RemoveButtonConnected onClick={() => removeOne(hint.id)} />}
          </div>
        </div>
      ))}
      <AuthoringButtonConnected
        action={addOne}
        style={{ marginLeft: '22px' }}
        className="btn btn-link"
      >
        Add hint
      </AuthoringButtonConnected>
    </Card.Content>
  </Card.Card>
);

const BottomOutHint: React.FC<HintProps> = ({ hint, updateOne, projectSlug, updateOneEditor }) => (
  <HintCard
    title={<>{'"Bottom out" hint'}</>}
    placeholder="Explain the answer for students who are still confused"
    hint={hint}
    updateOne={updateOne}
    projectSlug={projectSlug}
    updateOneEditor={updateOneEditor}
  />
);
