import React, { useCallback, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { getNodeText } from '../../../../../components/parts/janus-mcq/mcq-util';
import { QuillEditor } from '../../../../../components/parts/janus-text-flow/QuillEditor';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';
import { ScreenDeleteIcon } from '../../Flowchart/chart-components/ScreenDeleteIcon';
import { ScreenEditIcon } from '../../Flowchart/chart-components/ScreenEditIcon';

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

export const SpokeOptionsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
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
      <label className="form-label">Number of spokes</label>
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
        + Add Spoke
      </button>
    </div>
  );
};

const OptionsEditor: React.FC<{
  value: OptionsType;
  onChange: (v: OptionsType) => void;
  onDelete: () => void;
}> = ({ value, onChange, onDelete }) => {
  const [editorOpen, , openEditor, closeEditor] = useToggle(false);
  const [tempValue, setTempValue] = useState<{ value: OptionsNodes }>({ value: [] });
  const dispatch = useDispatch();

  const onSave = useCallback(() => {
    closeEditor();
    const newValue = {
      ...value,
      nodes: tempValue.value,
    };
    onChange(newValue);
    console.info('onSave', newValue);
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [closeEditor, onChange, tempValue.value, value]);

  const onEdit = useCallback(() => {
    openEditor();
    setTempValue({ value: value.nodes });
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
  }, [openEditor, value.nodes]);

  return (
    <div className="flex">
      <div className="flex-1">{getNodeText(value.nodes)}</div>
      <div className="flex-none">
        <button className="btn btn-link p-0 mr-1" onClick={onEdit}>
          <ScreenEditIcon />
        </button>
        <button className="btn btn-link p-0" onClick={onDelete}>
          <ScreenDeleteIcon />
        </button>
      </div>
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
              text: `Spoke ${count}`,
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
