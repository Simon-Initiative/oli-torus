import { EntityId } from '@reduxjs/toolkit';
import React, { useState } from 'react';
import { useDispatch } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { Icon } from '../../../../../components/misc/Icon';
import { replacePath } from '../flowchart-actions/replace-path';
import { AllPaths, DestinationPath, RuleTypes } from '../paths/path-types';
import { addComponentId, isDestinationPath } from '../paths/path-utils';

const ruleLabels: Record<RuleTypes, string> = {
  'unknown-reason-path': 'Never',
  'always-go-to': 'Always',
  'multiple-choice-correct': 'Correct',
  'multiple-choice-incorrect': 'Any Incorrect',
  'multiple-choice-common-error': 'Choice Common Error',
  'end-of-activity': 'End Of Activity',
  'dropdown-correct': 'Correct',
  'dropdown-incorrect': 'Any Incorrect',
  'dropdown-common-error': 'Choice Common Error',
};

interface Props {
  screenId: EntityId;
  questionType: string;
  availablePaths: AllPaths[];
  path: AllPaths;
  screenTitle: string;
  questionId: string | null;
  screens: Record<string, string>;
}

export const PathEditBox: React.FC<Props> = ({
  screenTitle,
  screenId,
  questionId,
  questionType,
  availablePaths,
  path,
  screens,
}) => {
  const [editMode, toggleEditMode] = useToggle(false);
  const className = path.completed ? 'path-editor-completed' : 'path-editor-incomplete';
  const dispatch = useDispatch();

  const onPathChanged = (oldPathId: string, newPath: AllPaths) => {
    dispatch(
      replacePath({
        oldPathId,
        newPath: addComponentId(newPath, questionId),
        screenId: screenId,
      }),
    );
  };

  return editMode ? (
    <PathEditor
      questionType={questionType}
      className={className}
      availablePaths={availablePaths}
      path={path}
      questionId={questionId}
      screens={screens}
      toggleEditMode={toggleEditMode}
      onChange={(newPath) => onPathChanged(path.id, newPath)}
    />
  ) : (
    <ReadOnlyPath
      path={path}
      screens={screens}
      toggleEditMode={toggleEditMode}
      className={className}
    />
  );
};

interface EditParams {
  className: string;
  availablePaths: AllPaths[];
  path: AllPaths;
  toggleEditMode: () => void;
  onChange: (path: AllPaths) => void;
  questionType: string;
  questionId: EntityId;
  screens: Record<string, string>;
}
const PathEditor: React.FC<EditParams> = ({
  className,
  availablePaths,
  path,
  toggleEditMode,
  screens,
  questionId,
  onChange,
  questionType,
}) => {
  const [workingPath, setWorkingPath] = useState<AllPaths>(path);
  const onEdit = (props: any) => setWorkingPath((p: AllPaths) => ({ ...p, ...props }));
  const onDestinationChange = (screenId: string) => onEdit({ destinationScreenId: screenId });
  const onSave = () => {
    onChange(workingPath);
    toggleEditMode();
  };

  return (
    <div className={className}>
      {questionId && <span>When {questionType} is</span>}

      {availablePaths.length === 1 && <label>{ruleLabels[availablePaths[0].type] || '???'}</label>}

      {availablePaths.length > 1 && (
        <select value={workingPath.type} onChange={(e) => onEdit({ type: e.target.value })}>
          {availablePaths.map((path, index) => (
            <option key={index} value={path.type}>
              {ruleLabels[path.type]}
            </option>
          ))}
        </select>
      )}

      <div className="param-box">
        {isDestinationPath(workingPath) && (
          <>
            Go to
            <DestinationPicker
              screens={screens}
              path={workingPath}
              onChange={onDestinationChange}
            />
          </>
        )}
        <Icon onClick={onSave} icon="save" />
      </div>
    </div>
  );
};

interface ROParams {
  className: string;
  path: AllPaths;
  toggleEditMode: () => void;
  screens: Record<string, string>;
}

const ReadOnlyPath: React.FC<ROParams> = ({ path, toggleEditMode, className, screens }) => {
  const label = ruleLabels[path.type] || '???';
  return (
    <div className={className}>
      <label>{label}</label>
      <div className="param-box">
        {isDestinationPath(path) && <DestinationLabel path={path} screens={screens} />}
        <Icon onClick={toggleEditMode} icon="edit" />
      </div>
    </div>
  );
};

interface DestinationPickerProps {
  path: DestinationPath;
  screens: Record<string, string>;
  onChange: (screenId: string) => void;
}
const DestinationPicker: React.FC<DestinationPickerProps> = ({ path, screens, onChange }) => {
  return (
    <select value={String(path.destinationScreenId)} onChange={(e) => onChange(e.target.value)}>
      {Object.keys(screens).map((screenId) => (
        <option key={screenId} value={screenId}>
          {screens[screenId]}
        </option>
      ))}
    </select>
  );
};

const DestinationLabel: React.FC<{ path: DestinationPath; screens: Record<string, string> }> = ({
  path,
  screens,
}) => {
  const screenTitle =
    path.destinationScreenId && screens ? screens[path.destinationScreenId] : 'Unknown';
  return <span className="path-param">{screenTitle}</span>;
};
