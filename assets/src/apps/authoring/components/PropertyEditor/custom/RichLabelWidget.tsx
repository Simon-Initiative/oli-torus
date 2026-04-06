import React, { useCallback, useState } from 'react';
import { WidgetProps } from '@rjsf/core';
import { JanusRichLabelEditorModal } from 'components/parts/common/JanusRichLabelEditorModal';
import {
  isRichLabelHtml,
  normalizeRichLabelForStorage,
  sanitizeRichLabelHtml,
} from 'utils/richOptionLabel';

/**
 * RJSF custom widget for single-string label/labelText fields on adaptive part components.
 * Supports plain text entry and rich formatting (sup, sub, bold, italic) via a Quill modal.
 */
export const RichLabelWidget: React.FC<WidgetProps> = ({
  id,
  value,
  onChange,
  onBlur,
  disabled,
  readonly,
}) => {
  const [showModal, setShowModal] = useState(false);
  const currentValue: string = typeof value === 'string' ? value : '';
  const sanitized = sanitizeRichLabelHtml(currentValue);
  const isRich = isRichLabelHtml(sanitized);

  const commit = useCallback(
    (normalized: string) => {
      onChange(normalized);
      setTimeout(() => onBlur(id, normalized), 0);
    },
    [id, onChange, onBlur],
  );

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange(e.target.value);
  };

  const handleInputBlur = () => {
    onBlur(id, currentValue);
  };

  const handleModalSave = useCallback(
    (saved: string) => {
      commit(normalizeRichLabelForStorage(saved));
    },
    [commit],
  );

  return (
    <div className="rich-label-widget">
      <style>{`
        .rich-label-widget {
          display: flex;
          align-items: center;
          gap: 6px;
        }
        .rich-label-widget-preview,
        .rich-label-widget-preview p,
        .rich-label-widget-preview div {
          margin: 0;
          font-size: inherit;
        }
        .rich-label-widget-input {
          flex: 1;
          min-width: 0;
        }
        .rich-label-widget-rich-preview {
          flex: 1;
          min-width: 0;
          padding: 6px 12px;
          border: 1px solid #ced4da;
          border-radius: 4px;
          background: #fff;
          font-size: 1rem;
          line-height: 1.5;
          min-height: 36px;
        }
        .rich-label-widget-format-btn {
          flex-shrink: 0;
          font-size: 12px;
          padding: 4px 8px;
          line-height: 1.2;
        }
      `}</style>

      {isRich ? (
        <div
          className="rich-label-widget-rich-preview rich-label-widget-preview"
          dangerouslySetInnerHTML={{ __html: sanitized }}
        />
      ) : (
        <input
          id={id}
          type="text"
          className="form-control rich-label-widget-input"
          value={currentValue}
          disabled={disabled || readonly}
          onChange={handleInputChange}
          onBlur={handleInputBlur}
        />
      )}

      <button
        type="button"
        title="Format label (bold, italic, superscript, subscript)"
        className="btn btn-outline-secondary rich-label-widget-format-btn"
        disabled={disabled || readonly}
        onClick={() => setShowModal(true)}
      >
        T<sup style={{ fontSize: '0.6em' }}>x</sup>
      </button>

      <JanusRichLabelEditorModal
        show={showModal}
        title="Edit label"
        value={currentValue}
        onHide={() => setShowModal(false)}
        onSave={handleModalSave}
        aria-label="Edit label with rich formatting"
      />
    </div>
  );
};

export default RichLabelWidget;
