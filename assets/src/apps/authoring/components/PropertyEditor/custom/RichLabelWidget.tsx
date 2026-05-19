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
 *
 * - Plain text label: renders a normal editable text input alongside a format button.
 * - Rich label (contains sup/sub/bold/italic): renders a read-only bordered preview
 *   (matching DropdownOptionsEditor style) with an edit-icon button.
 *
 * In both cases the format button opens JanusRichLabelEditorModal for rich editing.
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

  const handleModalSave = useCallback(
    (saved: string) => {
      const normalized = normalizeRichLabelForStorage(saved);
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

  return (
    <div className="flex align-items-center gap-1">
      <style>{`
        .rich-label-widget-preview,
        .rich-label-widget-preview p,
        .rich-label-widget-preview div {
          margin: 0;
        }
        .rich-label-widget-preview p,
        .rich-label-widget-preview div {
          line-height: 1.5;
        }
      `}</style>
      {isRich ? (
        /* Rich label — read-only preview matching DropdownOptionsEditor */
        <div
          id={id}
          className="flex-1 form-control rich-label-widget-preview"
          style={{
            minHeight: 38,
            cursor: 'default',
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <span dangerouslySetInnerHTML={{ __html: sanitized || '&nbsp;' }} />
        </div>
      ) : (
        /* Plain text label — normal editable input */
        <input
          id={id}
          type="text"
          className="flex-1 form-control"
          value={currentValue}
          disabled={disabled || readonly}
          onChange={handleInputChange}
          onBlur={handleInputBlur}
        />
      )}

      <div className="flex-none">
        <button
          type="button"
          className="btn btn-link btn-sm p-1 text-nowrap"
          disabled={disabled || readonly}
          onClick={() => setShowModal(true)}
          aria-label="Edit label formatting"
          title="Edit label formatting (bold, italic, superscript, subscript)"
        >
          <i className="fa-solid fa-pen-to-square" />
        </button>
      </div>

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
