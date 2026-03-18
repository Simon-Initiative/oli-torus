import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { TriggerAction, TriggerActionParams } from 'apps/authoring/types';
import { TriggerPromptEditor } from 'components/editing/elements/trigger/TriggerEditor';
import { AIIcon } from 'components/misc/AIIcon';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';

interface ActionTriggerEditorProps {
  action: TriggerAction;
  onChange: (changes: TriggerActionParams) => void;
  onDelete: (action: TriggerAction) => void;
}

const promptSamples = [
  'Acknowledge the incorrect attempt and ask one guiding question before giving any hint.',
  'Help the student identify the misconception behind this trap state without revealing the full answer.',
  'Coach the student through the next best step, using the current trap state as context.',
] as const;

const ActionTriggerEditor: React.FC<ActionTriggerEditorProps> = ({ action, onChange, onDelete }) => {
  const dispatch = useDispatch();
  const [prompt, setPrompt] = useState(action.params.prompt || '');
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);

  useEffect(() => {
    setPrompt(action.params.prompt || '');
  }, [action.params.prompt]);

  return (
    <div className="aa-action mb-3 rounded border p-3 bg-light">
      <div className="d-flex align-items-center justify-content-between mb-2">
        <div className="font-weight-bold">
          <AIIcon size="sm" className="inline mr-1" />
          Activation Point
        </div>
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

      <p className="mb-2">
        DOT will automatically open when this trap-state rule fires and will follow your prompt.
      </p>

      <div
        onFocusCapture={() => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
        onBlurCapture={() => dispatch(setCurrentPartPropertyFocus({ focus: true }))}
      >
        <TriggerPromptEditor
          value={prompt}
          onPromptChange={(value) => {
            setPrompt(value);
            onChange({ prompt: value });
          }}
          promptSamples={promptSamples}
          textareaClassName="mt-2 w-100 form-control"
          headingClassName="mt-0"
        />
      </div>

      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this activation point"
          deleteHandler={() => {
            onDelete(action);
            setShowConfirmDelete(false);
          }}
          cancelHandler={() => setShowConfirmDelete(false)}
        />
      )}
    </div>
  );
};

export default ActionTriggerEditor;
