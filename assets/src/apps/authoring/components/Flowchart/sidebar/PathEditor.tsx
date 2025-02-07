import React, { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { EntityId } from '@reduxjs/toolkit';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { clone } from '../../../../../utils/common';
import { selectAutoOpenPath } from '../../../store/flowchart/flowchart-slice';
import ConfirmDelete from '../../Modal/DeleteConfirmationModal';
import { deletePath } from '../flowchart-actions/delete-path';
import { replacePath } from '../flowchart-actions/replace-path';
import { AllPaths, DestinationPath } from '../paths/path-types';
import {
  addComponentId,
  addDestinationId,
  isComponentPath,
  isCorrectPath,
  isDestinationPath,
  isEndOfActivityPath,
  isIncorrectPath,
  sortByPriority,
} from '../paths/path-utils';

interface Props {
  screenId: EntityId;
  questionType: string;
  availablePaths: AllPaths[];
  path: AllPaths;

  questionId: string | null;
  screens: Record<string, string>;
  usedPathIds: string[];
}

export const PathEditBox: React.FC<Props> = ({
  screenId,
  questionId,
  questionType,
  availablePaths,
  usedPathIds,
  path,
  screens,
}) => {
  const autoOpen = useSelector(selectAutoOpenPath);
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

  const effectiveEditMode = editMode || autoOpen === path.id;

  return effectiveEditMode ? (
    <PathEditor
      questionType={questionType}
      className={className}
      availablePaths={availablePaths}
      path={path}
      screenId={screenId}
      questionId={questionId}
      screens={screens}
      toggleEditMode={toggleEditMode}
      usedPathIds={usedPathIds}
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
  usedPathIds: string[];
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
  usedPathIds,
}) => {
  const [workingPath, setWorkingPath] = useState<AllPaths>(clone(path));
  const onEdit = (props: Partial<AllPaths>) =>
    setWorkingPath((p: AllPaths) => ({ ...p, ...(props as any) }));
  const onDestinationChange = (screenId: string) => {
    console.log('I M IN onDestinationChange', { screenId });
    onEdit({ destinationScreenId: parseInt(screenId, 10) });
  };
  const [showDeleteConfirm, toggleDeleteConfirm] = useToggle(false);
  const dispatch = useDispatch();
  const onIdChange = (id: string) => {
    console.log('I M IN onIdChange', { id });
    if (id === workingPath.id) return;
    const target = availablePaths.find((p) => p.id === id);
    if (!target) return;
    if (isDestinationPath(target)) {
      const { destinationScreenId } = workingPath as DestinationPath;
      setWorkingPath(addDestinationId(target, destinationScreenId));
    } else {
      setWorkingPath(target);
    }
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
    dispatch(
      deletePath({
        pathId: workingPath.id,
        screenId: screenId,
      }),
    );
    toggleDeleteConfirm();
  };

  const availableWithCurrent = availablePaths.filter((pathOption) => {
    if (path.type === 'unknown-reason-path' && pathOption.type === 'unknown-reason-path') {
      // These are special, and you can have as many as you like.
      // But we don't want to show more than one in the dropdown list.
      return false;
    }

    // If this was the original path, we want to allow it
    if (pathOption.id === path.id) return true;

    // We don't want to allow the user to pick a path ID that is already in use
    return !usedPathIds.includes(pathOption.id);
  });

  if (availableWithCurrent.find((p) => p.id === workingPath.id) === undefined) {
    // In the case where we previously picked a path, but that path is no longer available to choose from the list.
    // Like if it was for option #4, but now we only have 3 options, we have to manually add it.
    availableWithCurrent.push(workingPath);
  }

  availableWithCurrent.sort(sortByPriority);

  const showQuestionLabel =
    isComponentPath(workingPath) || isCorrectPath(workingPath) || isIncorrectPath(workingPath);

  return (
    <div className={className}>
      {questionId && showQuestionLabel && <label>When {questionType} is</label>}

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

      {isDestinationPath(workingPath) && (
        <div className="destination-section">
          <label>Go to</label>
          <DestinationPicker
            screens={destinationScreens}
            path={workingPath}
            onChange={onDestinationChange}
          />
        </div>
      )}

      <div className="bottom-buttons">
        <button onClick={toggleDeleteConfirm} className="btn btn-danger">
          Delete
        </button>
        <button onClick={onSave} className="btn btn-primary">
          Done
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
  const prelabel = isEndOfActivityPath(path)
    ? 'Always '
    : isComponentPath(path) || isCorrectPath(path) || isIncorrectPath(path)
    ? 'If answer is '
    : '';
  const goToLabel = isDestinationPath(path) ? ' go to ' : '';
  return (
    <div className={className} onClick={toggleEditMode}>
      {prelabel}
      <div className="param-box">
        <span className="path-param">{path.label}</span>
      </div>
      {goToLabel}
      <div className="param-box">
        {isDestinationPath(path) && <DestinationLabel path={path} screens={screens} />}
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
  useEffect(() => {
    // On the first render, make sure a valid option is selected.
    const keys = Object.keys(screens);

    if (path.destinationScreenId !== -1 && !keys.includes(String(path.destinationScreenId))) {
      if (keys.length > 0) {
        onChange(Object.keys(screens)[0]);
      } else {
        onChange('-1');
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [onChange, screens]);

  return (
    <select value={String(path.destinationScreenId)} onChange={(e) => onChange(e.target.value)}>
      {Object.keys(screens).map((screenId) => (
        <option key={screenId} value={screenId}>
          {screens[screenId]}
        </option>
      ))}
      <option value="-1">-- Create new screen --</option>
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
