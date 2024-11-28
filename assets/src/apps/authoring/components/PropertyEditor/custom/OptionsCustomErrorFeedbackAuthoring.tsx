import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivityTree } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentSelection, setCurrentPartPropertyFocus } from '../../../store/parts/slice';

/*
 This component handles editing advanced feedback for a question type that has a fixed set of options.
 Right now, supports dropdown, will support multiple choice eventually.
*/

interface CorrectOptionProps {
  label: string;
  id: string;
  value: string[];
  onChange: (value: string[]) => void;
  onBlur: (id: string, value: string[]) => void;
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

export const OptionsCustomErrorFeedbackAuthoring: React.FC<CorrectOptionProps> = ({
  onChange,
  value,
  label,
  onBlur,
  id,
}) => {
  const currentPartSelection = useSelector(selectCurrentSelection);
  const activityTree = useSelector(selectCurrentActivityTree);
  const part = getPartDef(activityTree, currentPartSelection);
  const dispatch = useDispatch();
  // TODO - make this widget more generic, right now it's very tied to dropdowns.
  const options: string[] = part?.custom?.optionLabels || ['Option 1', 'Option 2'];
  const correctIndex = (part?.custom?.correctAnswer || 0) - 1; // -1 because the correct answer is specified in a 1-based index

  const OnOptionChanged = useCallback(
    (index) => (newOptionValue: string) => {
      const newFeedback = [...value];
      while (newFeedback.length <= index) {
        newFeedback.push('');
      }
      newFeedback[index] = newOptionValue;

      if (newFeedback.length > options.length) {
        // Used to have more options, we can trim the feedback now.
        newFeedback.splice(options.length);
      }

      onChange(newFeedback);
    },
    [onChange, options.length, value],
  );

  return (
    <div className="d-flex justify-content-between flex-column">
      <div className="form-label">{label}</div>

      {options.map((option, index) => {
        if (index === correctIndex) {
          return null;
        } // No advanced feedback for the correct answer, that's just the "correct" feedback
        return (
          <OptionFeedback
            onBlur={() => {
              onBlur(id, value);
              dispatch(setCurrentPartPropertyFocus({ focus: true }));
            }}
            key={index}
            index={index}
            option={option}
            feedback={value[index] || ''}
            onChange={OnOptionChanged(index)}
            onFocusHandler={() => {
              dispatch(setCurrentPartPropertyFocus({ focus: false }));
            }}
          />
        );
      })}
    </div>
  );
};

interface OptionFeedbackProps {
  option: string;
  feedback: string;
  index: number;
  onChange: (value: string) => void;
  onBlur: () => void;
  onFocusHandler: () => void;
}
const OptionFeedback: React.FC<OptionFeedbackProps> = ({
  option,
  index,
  onBlur,
  feedback,
  onChange,
  onFocusHandler,
}) => {
  const labelOption = option || `Option ${index + 1}`;
  return (
    <div className="form-group">
      <label>{labelOption}</label>
      <input
        onBlur={onBlur}
        className="form-control"
        value={feedback}
        onChange={(e) => onChange(e.target.value)}
        onFocus={onFocusHandler}
      />
    </div>
  );
};
