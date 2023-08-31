import React from 'react';
import { Descendant } from 'slate';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Description } from 'components/misc/Description';
import { Heading } from 'components/misc/Heading';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { DEFAULT_EDITOR, EditorType, SMALL_EDITOR_HEIGHT } from 'data/content/resource';
import { ProjectSlug } from 'data/types';
import { Feedback as FeedbackItem } from '../../types';
import { ModelEditorProps } from '../schema';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (score: number, content: Descendant[]) => void;
  onEditEditorType: (score: number, editor: EditorType) => void;
  projectSlug: ProjectSlug;
  onRequestMedia: any;
}

interface ItemProps extends FeedbackProps {
  feedback: FeedbackItem;
  score: number;
  onRequestMedia: any;
}

const Item = (props: ItemProps) => {
  const { feedback, score, editMode, onEditResponse } = props;

  return (
    <div className="my-3" key={feedback.id}>
      <Description>
        {score === 1 ? <Checkmark /> : <Cross />}
        Feedback for {score === 1 ? 'Correct' : 'Incorrect'} Answer:
      </Description>
      <SlateOrMarkdownEditor
        projectSlug={props.projectSlug}
        editMode={editMode}
        initialHeight={SMALL_EDITOR_HEIGHT}
        content={feedback.content}
        onEdit={(content) => onEditResponse(score, content)}
        onEditorTypeChange={(editor) => props.onEditEditorType(score, editor)}
        editorType={feedback.editor || DEFAULT_EDITOR}
        allowBlockElements={true}
      />
    </div>
  );
};

export const Feedback = (props: FeedbackProps) => {
  const { model } = props;

  return (
    <div className="my-5">
      <Heading
        title="Feedback"
        subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding."
        id="feedback"
      />

      {model.feedback.map((f: FeedbackItem, index) => (
        <Item key={index} {...props} feedback={f} score={index} />
      ))}
    </div>
  );
};
