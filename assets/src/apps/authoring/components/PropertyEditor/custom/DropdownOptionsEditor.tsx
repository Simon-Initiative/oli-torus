import React, { useCallback, useState } from 'react';
import { JanusRichLabelEditorModal } from 'components/parts/common/JanusRichLabelEditorModal';
import { sanitizeRichLabelHtml } from 'utils/richOptionLabel';
import { ScreenDeleteIcon } from '../../Flowchart/chart-components/ScreenDeleteIcon';

interface Props {
  id: string;
  value: string[];
  onChange: (value: string[]) => void;
  onBlur: (id: string, value: string[]) => void;
}

export const DropdownOptionsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const [editingIndex, setEditingIndex] = useState<number | null>(null);

  const editEntry = useCallback(
    (index) => (modified: string) => {
      const newValue = value.map((v, i) => (i === index ? modified : v));
      onChange(newValue);
      // The property editor has an interesting method of commiting changes on blur that could use a look, but think of this as a way
      // for the control to signal that it's time to commit the value. It's much more natural on controls like a text input, but even
      // then it's a bit awkward.
      setTimeout(() => {
        onBlur(id, newValue);
        onBlur('partPropertyElementFocus', []);
      }, 0);
    },
    [id, onBlur, onChange, value],
  );

  const deleteEntry = useCallback(
    (index) => () => {
      const newValue = value.filter((v, i) => i !== index);
      onChange(newValue);
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange, value],
  );

  const onAddOption = useCallback(() => {
    const newValue = [...value, `Option ${value.length + 1}`];
    onChange(newValue);
    setTimeout(() => onBlur(id, newValue), 0);
  }, [id, onBlur, onChange, value]);

  return (
    <div>
      <style>{`
        .dropdown-options-editor-label {
          display: flex;
          align-items: center;
          min-height: 38px;
        }
        .dropdown-options-editor-preview,
        .dropdown-options-editor-preview p,
        .dropdown-options-editor-preview div {
          margin: 0;
        }
        .dropdown-options-editor-preview p,
        .dropdown-options-editor-preview div {
          line-height: 1.5;
        }
      `}</style>
      <label className="form-label">Options</label>
      <div>
        {value.map((option, index) => (
          <OptionsEditor
            key={index}
            value={option}
            onDelete={deleteEntry(index)}
            onOpenFormat={() => setEditingIndex(index)}
            onFocus={() => onBlur('partPropertyElementFocus', [])}
          />
        ))}
      </div>

      <JanusRichLabelEditorModal
        show={editingIndex !== null}
        title="Option label"
        value={editingIndex !== null ? value[editingIndex] ?? '' : ''}
        onHide={() => setEditingIndex(null)}
        onSave={(html) => {
          if (editingIndex !== null) {
            editEntry(editingIndex)(html);
          }
        }}
        aria-label="Edit option label"
      />

      <button className="btn btn-primary" onClick={onAddOption}>
        + Add Option
      </button>
    </div>
  );
};

const OptionsEditor: React.FC<{
  value: string;
  onDelete: () => void;
  onOpenFormat: () => void;
  onFocus: () => void;
}> = ({ value, onDelete, onOpenFormat, onFocus }) => {
  const sanitized = sanitizeRichLabelHtml(value);

  return (
    <div className="flex mb-1 align-items-center gap-1">
      <div
        className="flex-1 form-control dropdown-options-editor-label"
        onFocus={onFocus}
        tabIndex={0}
      >
        <span
          className="dropdown-options-editor-preview"
          dangerouslySetInnerHTML={{ __html: sanitized || '&nbsp;' }}
        />
      </div>
      <div className="flex-none">
        <button
          type="button"
          className="btn btn-link btn-sm p-1 text-nowrap"
          onClick={onOpenFormat}
          aria-label="Edit option label formatting"
          title="Edit option label formatting"
        >
          <i className="fa-solid fa-pen-to-square" />
        </button>
      </div>
      <div className="flex-none">
        <button type="button" className="btn btn-link p-0" onClick={onDelete}>
          <ScreenDeleteIcon />
        </button>
      </div>
    </div>
  );
};
