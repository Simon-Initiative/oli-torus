import { EntityId } from '@reduxjs/toolkit';
import React, { useMemo, useState } from 'react';
import { useDispatch } from 'react-redux';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { Icon } from '../../../../../components/misc/Icon';
import ConfirmDelete from '../../Modal/DeleteConfirmationModal';
import { deletePath } from '../flowchart-actions/delete-path';
import { replacePath } from '../flowchart-actions/replace-path';
import { AllPaths, DestinationPath, DestinationPaths, RuleTypes } from '../paths/path-types';
import { addComponentId, addDestinationId, isDestinationPath } from '../paths/path-utils';

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
      screenId={screenId}
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
  questionId: string | null;
  screens: Record<string, string>;
  screenId: EntityId;
}
const PathEditor: React.FC<EditParams> = ({
  className,
  availablePaths,
  path,
  toggleEditMode,
  screens,
  questionId,
  screenId,
  onChange,
  questionType,
}) => {
  const [workingPath, setWorkingPath] = useState<AllPaths>(path);
  const onEdit = (props: any) => setWorkingPath((p: AllPaths) => ({ ...p, ...props }));
  const onDestinationChange = (screenId: string) => onEdit({ destinationScreenId: screenId });
  const [showDeleteConfirm, toggleDeleteConfirm] = useToggle(false);
  const dispatch = useDispatch();
  const onIdChange = (id: string) => {
    if (id === workingPath.id) return;
    const target = availablePaths.find((p) => p.id === id);
    if (!target) return;
    const { destinationScreenId } = workingPath as DestinationPath;
    onEdit(addDestinationId(target, destinationScreenId));
  };
  const onSave = () => {
    onChange(workingPath);
    toggleEditMode();
  };

  const destinationScreens = useMemo(() => {
    // Don't let the user pick the this screen as the destination
    const filtered = {
      ...screens,
    };
    delete filtered[String(screenId)];
    return filtered;
  }, [screens, screenId]);

  const onDelete = () => {
    //onDeleteScreen(data.resourceId!);
    dispatch(
      deletePath({
        pathId: workingPath.id,
        screenId: screenId,
      }),
    );
    toggleDeleteConfirm();
  };

  const availableWithCurrent = [workingPath, ...availablePaths];

  return (
    <div className={className}>
      {questionId && <span>When {questionType} is</span>}

      {availableWithCurrent.length === 1 && <label>{availableWithCurrent[0].label}</label>}

      {availableWithCurrent.length > 1 && (
        <select value={workingPath.id} onChange={(e) => onIdChange(e.target.value)}>
          {availableWithCurrent.map((path, index) => (
            <option key={index} value={path.id}>
              {path.label}
            </option>
          ))}
        </select>
      )}

      <div className="param-box">
        {isDestinationPath(workingPath) && (
          <>
            Go to
            <DestinationPicker
              screens={destinationScreens}
              path={workingPath}
              onChange={onDestinationChange}
            />
          </>
        )}
        <button onClick={toggleDeleteConfirm} className="icon-button">
          <Icon icon="trash" />
        </button>
        <button onClick={onSave} className="icon-button">
          <Icon icon="save" />
        </button>
      </div>
      {showDeleteConfirm && (
        <ConfirmDelete
          show={true}
          elementType="Rule"
          elementName={workingPath.label}
          deleteHandler={onDelete}
          cancelHandler={toggleDeleteConfirm}
        />
      )}
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
  return (
    <div className={className}>
      <label>{path.label}</label>
      <div className="param-box">
        {isDestinationPath(path) && <DestinationLabel path={path} screens={screens} />}
        <button onClick={toggleEditMode} className="icon-button">
          <Icon icon="edit" />
        </button>
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
