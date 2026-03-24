import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import ReactQuill from 'react-quill';
import { normalizeRichLabelForStorage } from '../../../utils/richOptionLabel';

const QUILL_SNOW_CSS_ID = 'quill-snow-css-janus-rich-label';

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

const quillFormats = ['bold', 'italic', 'script'];

/**
 * Minimal rich-text modal for short Janus labels (sup/sub/bold/italic).
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
    if (typeof document === 'undefined') {
      return;
    }
    if (!document.getElementById(QUILL_SNOW_CSS_ID)) {
      const link = document.createElement('link');
      link.id = QUILL_SNOW_CSS_ID;
      link.rel = 'stylesheet';
      link.href = 'https://cdn.quilljs.com/1.3.6/quill.snow.css';
      document.head.appendChild(link);
    }
  }, []);

  useEffect(() => {
    if (show) {
      setDraft(value || '');
    }
  }, [show, value]);

  const handleSave = useCallback(() => {
    onSave(normalizeRichLabelForStorage(draft));
    onHide();
  }, [draft, onHide, onSave]);

  const modules = useMemo(
    () => ({
      toolbar: [['bold', 'italic'], [{ script: 'sub' }, { script: 'super' }]],
    }),
    [],
  );

  return (
    <Modal show={show} onHide={onHide} centered aria-label={ariaLabel}>
      <Modal.Header closeButton>
        <Modal.Title>{title}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <div className="janus-rich-label-editor-quill">
          <ReactQuill
            theme="snow"
            value={draft}
            onChange={setDraft}
            modules={modules}
            formats={quillFormats}
            style={{ minHeight: 120 }}
          />
        </div>
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
