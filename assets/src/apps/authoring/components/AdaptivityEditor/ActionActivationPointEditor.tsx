import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { ActivationPointAction, ActivationPointActionParams } from 'apps/authoring/types';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';

interface ActionActivationPointEditorProps {
  action: ActivationPointAction;
  onChange: (changes: ActivationPointActionParams) => void;
  onDelete: (action: ActivationPointAction) => void;
}

const ActionActivationPointEditor: React.FC<ActionActivationPointEditorProps> = (props) => {
  const { action, onChange, onDelete } = props;
  const [prompt, setPrompt] = useState(action.params.prompt || '');
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  useEffect(() => setPrompt(action.params.prompt || ''), [action.params.prompt]);

  const handleBlur = () => {
    if (prompt !== action.params.prompt) {
      onChange({ prompt });
    }
  };

  return (
    <div className="aa-action aa-activation-point mb-2">
      <div className="d-flex align-items-center mb-1">
        <i className="fa fa-bolt mr-2" />
        <strong className="mr-auto">Activation Point</strong>
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
      <div className="alert alert-warning py-1 px-2 mb-2" style={{ fontSize: '12px' }}>
        <i className="fa fa-exclamation-triangle mr-1" />
        Best Practice: Avoid adding both feedback and a trap state activation point for the same
        rule. This may overwhelm the student.
      </div>
      <textarea
        className="form-control form-control-sm"
        rows={3}
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        onBlur={handleBlur}
        placeholder="Enter prompt for the AI agent (e.g., The student made an error with X. Help them understand Y.)"
      />
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this activation point action"
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

export default ActionActivationPointEditor;
