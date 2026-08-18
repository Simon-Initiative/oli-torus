import React, { useCallback, useState } from 'react';
import { JanusRichLabelEditor } from 'components/parts/common/JanusRichLabelEditor';
import { JanusRichLabelEditorModal } from 'components/parts/common/JanusRichLabelEditorModal';
import {
  isRichLabelHtml,
  normalizeRichLabelForStorage,
  sanitizeRichLabelHtml,
} from 'utils/richOptionLabel';

export interface RichLabelFieldProps {
  id?: string;
  value: string;
  onChange: (value: string) => void;
  onBlur?: (value: string) => void;
  disabled?: boolean;
  placeholder?: string;
  /** Opens as the modal title / aria-label */
  modalTitle?: string;
  /** Use a textarea instead of a single-line input for plain text */
  multiline?: boolean;
  rows?: number;
  className?: string;
  inputClassName?: string;
  /** Extra class on the outer flex row */
  rowClassName?: string;
  /** Render Quill inline instead of plain input + nested modal */
  inline?: boolean;
}

const previewStyle: React.CSSProperties = {
  minHeight: 38,
  cursor: 'default',
  display: 'flex',
  alignItems: 'center',
};

/**
 * Shared authoring control for short rich labels (sup/sub/bold/italic).
 * Used by RichLabelWidget and custom item-editor modals.
 */
export const RichLabelField: React.FC<RichLabelFieldProps> = ({
  id,
  value,
  onChange,
  onBlur,
  disabled = false,
  placeholder,
  modalTitle = 'Edit label',
  multiline = false,
  rows = 3,
  className,
  inputClassName = 'flex-1 form-control',
  rowClassName = 'flex align-items-center gap-1',
  inline = false,
}) => {
  const [showModal, setShowModal] = useState(false);
  const currentValue = typeof value === 'string' ? value : '';
  const sanitized = sanitizeRichLabelHtml(currentValue);
  const isRich = isRichLabelHtml(sanitized);

  const handleModalSave = useCallback(
    (saved: string) => {
      const normalized = normalizeRichLabelForStorage(saved);
      onChange(normalized);
      onBlur?.(normalized);
    },
    [onBlur, onChange],
  );

  const handlePlainChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    onChange(e.target.value);
  };

  const handlePlainBlur = () => {
    onBlur?.(currentValue);
  };

  if (inline) {
    return (
      <div className={className}>
        <JanusRichLabelEditor
          id={id}
          value={currentValue}
          onChange={onChange}
          disabled={disabled}
        />
      </div>
    );
  }

  return (
    <div className={className}>
      <div className={rowClassName}>
        <style>{`
          .rich-label-field-preview,
          .rich-label-field-preview p,
          .rich-label-field-preview div {
            margin: 0;
          }
          .rich-label-field-preview p,
          .rich-label-field-preview div {
            line-height: 1.5;
          }
        `}</style>
        {isRich ? (
          <div
            id={id}
            className={`${inputClassName} rich-label-field-preview`}
            style={previewStyle}
          >
            <span dangerouslySetInnerHTML={{ __html: sanitized || '&nbsp;' }} />
          </div>
        ) : multiline ? (
          <textarea
            id={id}
            className={inputClassName}
            rows={rows}
            value={currentValue}
            disabled={disabled}
            placeholder={placeholder}
            onChange={handlePlainChange}
            onBlur={handlePlainBlur}
          />
        ) : (
          <input
            id={id}
            type="text"
            className={inputClassName}
            value={currentValue}
            disabled={disabled}
            placeholder={placeholder}
            onChange={handlePlainChange}
            onBlur={handlePlainBlur}
          />
        )}

        <div className="flex-none">
          <button
            type="button"
            className="btn btn-link btn-sm p-1 text-nowrap"
            disabled={disabled}
            onClick={() => setShowModal(true)}
            aria-label="Edit label formatting"
            title="Edit label formatting (bold, italic, superscript, subscript)"
          >
            <i className="fa-solid fa-pen-to-square" />
          </button>
        </div>

        <JanusRichLabelEditorModal
          show={showModal}
          title={modalTitle}
          value={currentValue}
          onHide={() => setShowModal(false)}
          onSave={handleModalSave}
          aria-label={`${modalTitle} with rich formatting`}
        />
      </div>
    </div>
  );
};

export default RichLabelField;
