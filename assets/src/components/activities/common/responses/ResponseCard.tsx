import React from 'react';
import { Descendant } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Response } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';
import { AuthoringCheckboxConnected } from '../authoring/AuthoringCheckbox';

interface Props {
  title: React.ReactNode;
  response: Response;
  updateFeedbackEditor: (responseId: ID, editor: EditorType) => void;
  updateFeedback: (responseId: ID, content: Descendant[]) => void;
  updateCorrectness: (responseId: ID, correct: boolean) => void;
  removeResponse: (responseId: ID) => void;
}
export const ResponseCard: React.FC<Props> = (props) => {
  const { projectSlug } = useAuthoringElementContext();

  const onEditorTypeChange = (editor: EditorType) =>
    props.updateFeedbackEditor!(props.response.id, editor);

  const editorType = props.response.feedback.editor || DEFAULT_EDITOR;

  return (
    <Card.Card>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">{props.title}</div>
        <div className="flex-grow-1"></div>
        <AuthoringCheckboxConnected
          label="Correct"
          id={props.response.id + '-correct'}
          value={!!props.response.score}
          onChange={(value) => props.updateCorrectness(props.response.id, value)}
        />
        <RemoveButtonConnected onClick={() => props.removeResponse(props.response.id)} />
      </Card.Title>
      <Card.Content>
        <SlateOrMarkdownEditor
          placeholder="Explain why the student might have arrived at this answer"
          content={props.response.feedback.content}
          onEdit={(content) => props.updateFeedback(props.response.id, content)}
          onEditorTypeChange={onEditorTypeChange}
          allowBlockElements={true}
          editorType={editorType}
          editMode={true}
          projectSlug={projectSlug}
        />

        {props.children}
      </Card.Content>
    </Card.Card>
  );
};
