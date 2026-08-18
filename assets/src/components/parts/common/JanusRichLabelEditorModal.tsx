import React, { useCallback, useEffect, useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { normalizeRichLabelForStorage } from '../../../utils/richOptionLabel';
import { JanusRichLabelEditor } from './JanusRichLabelEditor';

export interface JanusRichLabelEditorModalProps {
  show: boolean;
  title?: string;
  /** Initial / current HTML (may be plain text) */
  value: string;
  onHide: () => void;
  onSave: (sanitizedHtml: string) => void;
  /** Optional accessible label for the dialog */
  'aria-label'?: string;
}

/**
 * Modal wrapper for short Janus label rich-text editing.
 * Shared across part property editors; first used by dropdown option labels.
 */
export const JanusRichLabelEditorModal: React.FC<JanusRichLabelEditorModalProps> = ({
  show,
  title = 'Edit label',
  value,
  onHide,
  onSave,
  'aria-label': ariaLabel,
}) => {
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    if (show) {
      setDraft(value || '');
    }
  }, [show, value]);

  const handleSave = useCallback(() => {
    onSave(normalizeRichLabelForStorage(draft));
    onHide();
  }, [draft, onHide, onSave]);

  return (
    <Modal show={show} onHide={onHide} centered aria-label={ariaLabel}>
      <Modal.Header closeButton>
        <Modal.Title>{title}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <JanusRichLabelEditor value={draft} onChange={setDraft} />
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onHide}>
          Cancel
        </Button>
        <Button variant="primary" onClick={handleSave}>
          Save
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default JanusRichLabelEditorModal;
