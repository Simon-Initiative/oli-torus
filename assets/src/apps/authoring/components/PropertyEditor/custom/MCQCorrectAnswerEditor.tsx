import React, { useCallback, useMemo } from 'react';
import { useSelector } from 'react-redux';
import { selectCurrentSelection } from '../../../store/parts/slice';
import { IMCQPartLayout } from '../../../../delivery/store/features/activities/slice';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
import { getNodeText } from '../../../../../components/parts/janus-mcq/mcq-util';
import { ToggleOption } from '../../../../../components/common/ThreeStateToggle';

interface Props {
  id: string;
  value: boolean[];
  onChange: (value: boolean[]) => void;
  onBlur: (id: string, value: boolean[]) => void;
}

const getPartDef = (currentActivityTree: any, currentPartSelection: any) => {
  try {
    let partDef;
    for (let i = 0; i < currentActivityTree.length; i++) {
      const activity = currentActivityTree[i];
      partDef = activity.content?.partsLayout.find((part: any) => part.id === currentPartSelection);
      if (partDef) {
        break;
      }
    }
    return partDef;
  } catch (e) {
    console.log(e);
    return null;
  }
};

export const MCQCorrectAnswerEditor: React.FC<Props> = ({ value, onChange, id, onBlur }) => {
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);
  const part = getPartDef(activityTree, currentPartSelection) as IMCQPartLayout;
  const multiSelect = !!part?.custom?.multipleSelection;
  const options = useMemo(
    () => part?.custom?.mcqItems.map((v) => getNodeText(v.nodes)) || ['Option 1', 'Option 2'],
    [part],
  );

  const onSelect = useCallback(
    (e) => {
      const newVal = parseInt(e.currentTarget.value, 10);
      const correct = options.map((_, i) => i === newVal);
      onChange(correct);
      setTimeout(() => onBlur(id, correct), 0);
    },
    [id, onBlur, onChange, options],
  );

  if (multiSelect)
    return (
      <MCQCorrectMultiselectAnswerEditor
        value={value}
        onChange={onChange}
        id={id}
        onBlur={onBlur}
        options={options}
      />
    );

  const correctIndex = value.findIndex((v) => v);

  return (
    <div>
      <label className="form-label">Correct Answer</label>
      <select className="form-control" value={correctIndex} onChange={onSelect}>
        {options.map((option: string, index: number) => (
          <option key={index} value={index}>
            {option}
          </option>
        ))}
      </select>
    </div>
  );
};

const MCQCorrectMultiselectAnswerEditor: React.FC<Props & { options: string[] }> = ({
  value,
  options,
  onChange,
  id,
  onBlur,
}) => {
  const toggleOption = useCallback(
    (i: number) => () => {
      const newValue = [...value];
      newValue[i] = !newValue[i];
      onChange(newValue);
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange, value],
  );

  return (
    <div>
      <label className="form-label">Correct Answer</label>
      {options.map((option: string, index: number) => (
        <div key={index}>
          <input type="checkbox" checked={value[index]} onChange={toggleOption(index)} />
          <label>&nbsp;{option}</label>
        </div>
      ))}
    </div>
  );
};
