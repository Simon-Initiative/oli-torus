import React, { useCallback, useMemo } from 'react';
import { useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentSelection } from '../../../store/parts/slice';

interface Props {
  id: string;
  label: string;
  value?: number;
  onChange: (value: number) => void;
  onBlur: (id: string, value: number) => void;
}

const getPartDef = (currentActivityTree: any, currentPartSelection: any) => {
  try {
    for (let i = 0; i < currentActivityTree.length; i++) {
      const activity = currentActivityTree[i];
      const partDef = activity.content?.partsLayout.find(
        (part: any) => part.id === currentPartSelection,
      );
      if (partDef) {
        return partDef;
      }
    }
    return null;
  } catch (_e) {
    return null;
  }
};

export const TextSliderCorrectAnswerPicker: React.FC<Props> = ({
  id,
  label,
  value,
  onChange,
  onBlur,
}) => {
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);
  const part = getPartDef(activityTree, currentPartSelection);

  const options = useMemo(
    () => part?.custom?.sliderOptionLabels || ['Label 1', 'Label 2', 'Label 3'],
    [part],
  );

  const selectedValue = typeof value === 'number' ? value : 0;

  const onSelect = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) => {
      const newValue = parseInt(e.currentTarget.value, 10);
      onChange(newValue);
      setTimeout(() => onBlur(id, newValue), 0);
    },
    [id, onBlur, onChange],
  );

  return (
    <div className="d-flex justify-content-between flex-column">
      <div className="form-label">{label}</div>
      <select className="form-control form-select" value={selectedValue} onChange={onSelect}>
        {options.map((option: string, index: number) => (
          <option key={`${index}-${option}`} value={index}>
            {option}
          </option>
        ))}
      </select>
    </div>
  );
};
