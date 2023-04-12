import { Objective } from '../../../../../data/content/objective';
import { selectAllObjectivesMap } from '../../../store/app/slice';
import { LearningObjectivesModal } from './LearningObjectivesModal';
import React, { useCallback, useState } from 'react';
import { useSelector } from 'react-redux';

interface SingleObjectiveProps {
  objective: Objective;
}
const SingleObjective: React.FC<SingleObjectiveProps> = ({ objective }) => {
  return <li>{objective.title}</li>;
};

interface CustomFieldProps {
  value: number[]; // Array of objective ID's attached to this screen
  disabled: boolean;
  readonly: boolean;

  onChange: (items: number[]) => void;
  onBlur: (id: string, items: number[]) => void;
  id: string;
}

// Component rendered in the right-hand column for editing learning objectives.
export const LearningObjectivesEditor: React.FC<CustomFieldProps> = ({
  disabled,
  value,
  readonly,
  onChange,
  onBlur,
  id,
}) => {
  const [editorWindowOpen, setEditorWindowOpen] = useState(false);
  const handleOpenEditorWindow = useCallback(() => setEditorWindowOpen(true), []);
  const handleCloseEditorWindow = useCallback(() => {
    onBlur(id, value);
    setEditorWindowOpen(false);
  }, []);
  const objectiveMap = useSelector(selectAllObjectivesMap);

  const onObjectivesChanged = useCallback(
    (value: number[]) => {
      onChange(value);
    },
    [onChange],
  );

  if (!Array.isArray(value)) {
    return null;
  }

  return (
    <div>
      <label className="form-label">Learning Objectives</label>
      <ul className="list-unstyled objectives-flat-list">
        {value
          .map((objectiveId) => objectiveMap[String(objectiveId)])
          .filter((objective) => !!objective)
          .map((objective) => (
            <SingleObjective key={objective.id} objective={objective} />
          ))}
      </ul>
      <button
        className="btn btn-primary btn-block"
        type="button"
        disabled={disabled || editorWindowOpen}
        onClick={handleOpenEditorWindow}
      >
        Edit Objectives
      </button>
      {editorWindowOpen && (
        <LearningObjectivesModal
          readonly={readonly}
          currentObjectives={value}
          objectiveMap={objectiveMap}
          handleClose={handleCloseEditorWindow}
          onChange={onObjectivesChanged}
        />
      )}
    </div>
  );
};
