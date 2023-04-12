import React, { useCallback, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentSelection } from '../../../store/parts/slice';
interface CorrectOptionProps {
  label: string;
  id: string;
  value: number;
  onChange: (value: number) => void;
  onBlur: (id: string, value: number) => void;
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

export const OptionsCorrectPicker: React.FC<CorrectOptionProps> = ({
  onChange,
  value,
  label,
  onBlur,
  id,
}) => {
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);
  const part = getPartDef(activityTree, currentPartSelection);

  // TODO - make this widget more generic, right now it's very tied to dropdowns.
  const options = part?.custom?.optionLabels || ['Option 1', 'Option 2'];

  const onSelect = useCallback(
    (e) => {
      const newVal = parseInt(e.currentTarget.value, 10);
      onChange(newVal);
    },
    [onChange],
  );

  return (
    <div className="d-flex justify-content-between flex-column">
      <div className="form-label">{label}</div>
      <select
        onChange={onSelect}
        onBlur={() => onBlur(id, value)}
        className="form-control form-select"
        value={value === undefined ? -1 : value}
      >
        {options.map((option: string, index: number) => (
          <option value={index + 1} key={index}>
            {option}
          </option>
        ))}
      </select>
    </div>
  );
};
