import React, { useCallback } from 'react';
import { ScreenDeleteIcon } from '../../Flowchart/chart-components/ScreenDeleteIcon';

interface Props {
  id: string;
  value: string[];
  onChange: (value: string[]) => void;
  onBlur: (id: string, value: string[]) => void;
}

export const DropdownOptionsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
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
      <label className="form-label">Options</label>
      <div>
        {value.map((option, index) => (
          <OptionsEditor
            key={index}
            value={option}
            onChange={editEntry(index)}
            onDelete={deleteEntry(index)}
            onFocus={() => onBlur('partPropertyElementFocus', [])}
          />
        ))}
      </div>

      <button className="btn btn-primary" onClick={onAddOption}>
        + Add Option
      </button>
    </div>
  );
};

const OptionsEditor: React.FC<{
  value: string;
  onChange: (v: string) => void;
  onDelete: () => void;
  onFocus: () => void;
}> = ({ value, onChange, onDelete, onFocus }) => {
  return (
    <div className="flex mb-1">
      <div className="flex-1">
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={onFocus}
        />
      </div>
      <div className="flex-none">
        <button className="btn btn-link p-0" onClick={onDelete}>
          <ScreenDeleteIcon />
        </button>
      </div>
    </div>
  );
};
