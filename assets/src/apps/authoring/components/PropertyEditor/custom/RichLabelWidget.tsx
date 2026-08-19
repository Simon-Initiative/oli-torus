import React, { useCallback } from 'react';
import { WidgetProps } from '@rjsf/core';
import { RichLabelField } from 'components/parts/common/RichLabelField';

/**
 * RJSF custom widget for single-string label/labelText fields on adaptive part components.
 *
 * - Plain text label: renders a normal editable text input alongside a format button.
 * - Rich label (contains sup/sub/bold/italic): renders a read-only bordered preview
 *   with an edit-icon button.
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
  label,
}) => {
  const currentValue: string = typeof value === 'string' ? value : '';

  const handleChange = useCallback(
    (next: string) => {
      onChange(next);
    },
    [onChange],
  );

  const handleBlur = useCallback(
    (next: string) => {
      setTimeout(() => onBlur(id, next), 0);
    },
    [id, onBlur],
  );

  return (
    <div>
      {label && (
        <label htmlFor={id} className="form-label">
          {label}
        </label>
      )}
      <RichLabelField
        id={id}
        value={currentValue}
        onChange={handleChange}
        onBlur={handleBlur}
        disabled={disabled || readonly}
        modalTitle="Edit label"
      />
    </div>
  );
};

export default RichLabelWidget;
