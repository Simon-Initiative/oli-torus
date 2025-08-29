import React from 'react';
import { Descendant } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Response } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Card } from 'components/misc/Card';
import { TextDirection } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';
import { AuthoringCheckboxConnected } from '../authoring/AuthoringCheckbox';
import { ScoreInput } from './ScoreInput';

interface Props {
  title: React.ReactNode;
  response: Response;
  updateFeedbackTextDirection: (responseId: ID, textDirection: TextDirection) => void;
  updateFeedbackEditor: (responseId: ID, editor: EditorType) => void;
  updateFeedback: (responseId: ID, content: Descendant[]) => void;
  updateCorrectness: (responseId: ID, correct: boolean) => void;
  removeResponse: (responseId: ID) => void;
  updateScore?: (responseId: ID, score: number) => void;
  customScoring?: boolean;
  editMode?: boolean;
}

export const ResponseCard: React.FC<Props> = (props) => {
  const { projectSlug } = useAuthoringElementContext();
  const editMode = props.editMode ?? true;

  const onEditorTypeChange = (editor: EditorType) =>
    props.updateFeedbackEditor!(props.response.id, editor);

  const onChangeTextDirection = (textDirection: TextDirection) =>
    props.updateFeedbackTextDirection!(props.response.id, textDirection);

  const onScoreChange = (score: number) => {
    props.updateScore && props.updateScore(props.response.id, score);
  };

  const editorType = props.response.feedback.editor || DEFAULT_EDITOR;

  return (
    <Card.Card>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">{props.title}</div>
        <div className="flex-grow-1"></div>

        {
          /* No custom scoring, so a correct/incorrect checkbox that sets 1/0 score */
          props.customScoring || (
            <AuthoringCheckboxConnected
              label="Correct"
              id={props.response.id + '-correct'}
              value={!!props.response.score}
              onChange={(value) => props.updateCorrectness(props.response.id, value)}
            />
          )
        }

        {props.customScoring && (
          /* We are using custom scoring, so prompt for a score instead of correct/incorrect */
          <ScoreInput score={props.response.score} onChange={onScoreChange} editMode={editMode}>
            Score:
          </ScoreInput>
        )}

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
          editMode={editMode}
          projectSlug={projectSlug}
          textDirection={props.response.feedback.textDirection}
          onChangeTextDirection={onChangeTextDirection}
        />

        {props.children}
      </Card.Content>
    </Card.Card>
  );
};
