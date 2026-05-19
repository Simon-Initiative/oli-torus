import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { ActivationPointAction, ActivationPointActionParams } from 'apps/authoring/types';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';

interface ActionLLMFeedbackEditorProps {
  action: ActivationPointAction;
  onChange: (changes: ActivationPointActionParams) => void;
  onDelete: (action: ActivationPointAction) => void;
}

const ActionLLMFeedbackEditor: React.FC<ActionLLMFeedbackEditorProps> = (props) => {
  const { action, onChange, onDelete } = props;
  const [prompt, setPrompt] = useState(action.params.prompt || '');
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  useEffect(() => setPrompt(action.params.prompt || ''), [action.params.prompt]);

  const handleBlur = () => {
    if (prompt !== action.params.prompt) {
      onChange({ prompt, kind: 'feedback' });
    }
  };

  return (
    <div className="aa-action aa-llm-feedback mb-2">
      <div className="d-flex align-items-center mb-1">
        <i className="fa fa-robot mr-2" />
        <strong className="mr-auto">AI-Generated Feedback</strong>
        <OverlayTrigger
          placement="top"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              Delete Action
            </Tooltip>
          }
        >
          <span>
            <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
              <i className="fa fa-trash-alt" />
            </button>
          </span>
        </OverlayTrigger>
      </div>
      <div className="alert alert-info py-1 px-2 mb-2" style={{ fontSize: '12px' }}>
        <i className="fa fa-info-circle mr-1" />
        The LLM will use this prompt along with the student&apos;s response and screen content to
        generate personalized feedback.
      </div>
      <textarea
        className="form-control form-control-sm"
        rows={3}
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        onBlur={handleBlur}
        placeholder="Enter prompt for AI feedback (e.g., The student confused X with Y. Guide them toward understanding the difference without revealing the answer.)"
      />
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this AI-generated feedback action"
          deleteHandler={() => {
            onDelete(action);
            setShowConfirmDelete(false);
          }}
          cancelHandler={() => {
            setShowConfirmDelete(false);
          }}
        />
      )}
    </div>
  );
};

export default ActionLLMFeedbackEditor;
