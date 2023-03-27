import React, { useCallback, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { QuillEditor } from '../../../../../components/parts/janus-text-flow/QuillEditor';
import { getNodeText } from '../../../../../components/parts/janus-mcq/mcq-util';

type OptionsNodes = Record<string, any>[];

type OptionsType = {
  nodes: OptionsNodes;
};

interface Props {
  id: string;
  value: OptionsType[];
  onChange: (value: OptionsType[]) => void;
  onBlur: (id: string, value: OptionsType[]) => void;
}

export const MCQOptionsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const editEntry = useCallback(
    (index) => (modified: OptionsType) => {
      const newValue = value.map((v, i) => (i === index ? modified : v));
      onChange(newValue);
      // The property editor has an interesting method of commiting changes on blur that could use a look, but think of this as a way
      // for the control to signal that it's time to commit the value. It's much more natural on controls like a text input, but even
      // then it's a bit awkward.
      setTimeout(() => onBlur(id, newValue), 0);
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
    const newValue = [...value, optionTemplate(value.length + 1)];
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
  value: OptionsType;
  onChange: (v: OptionsType) => void;
  onDelete: () => void;
}> = ({ value, onChange, onDelete }) => {
  const [editorOpen, _, openEditor, closeEditor] = useToggle(false);
  const [tempValue, setTempValue] = useState<{ value: OptionsNodes }>({ value: [] });

  const onSave = useCallback(() => {
    closeEditor();
    const newValue = {
      ...value,
      nodes: tempValue.value,
    };
    onChange(newValue);
    console.info('onSave', newValue);
  }, [closeEditor, onChange, tempValue.value, value]);

  const onEdit = useCallback(() => {
    openEditor();
    setTempValue({ value: value.nodes });
  }, [openEditor, value.nodes]);

  return (
    <div className="d-flex">
      <div className="col">{getNodeText(value.nodes)}</div>
      <button className="btn btn-secondary" onClick={onEdit}>
        e
      </button>
      <button className="btn btn-secondary" onClick={onDelete}>
        -
      </button>
      {editorOpen && (
        <AdvancedAuthoringModal show={true}>
          <Modal.Body>
            <QuillEditor
              tree={value.nodes}
              onChange={setTempValue}
              onSave={() => console.info('onSave')}
              onCancel={() => console.info('onCancel')}
            />
          </Modal.Body>
          <Modal.Footer>
            <button onClick={onSave} className="btn btn-primary">
              Save
            </button>
          </Modal.Footer>
        </AdvancedAuthoringModal>
      )}
    </div>
  );
};

const optionTemplate = (count: number) => ({
  nodes: [
    {
      tag: 'p',
      style: {},
      children: [
        {
          tag: 'span',
          style: {},
          children: [
            {
              tag: 'text',
              text: `Option Number ${count}`,
              style: {},
              children: [],
            },
          ],
        },
      ],
    },
  ],
  scoreValue: 0,
});
