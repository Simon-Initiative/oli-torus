import { EntityId } from '@reduxjs/toolkit';
import React from 'react';
import { useDispatch } from 'react-redux';
import { addPath } from '../flowchart-actions/add-path';
import { AllPaths } from '../paths/path-types';
import { sortByPriority } from '../paths/path-utils';
import { PathEditBox } from './PathEditor';

interface Props {
  questionType: string;
  availablePaths: AllPaths[];
  paths: AllPaths[];
  screenId: EntityId;
  questionId: string | null;
  screens: Record<string, string>;
}

export const PathsEditor: React.FC<Props> = ({
  screenId,
  questionId,
  questionType,
  availablePaths,
  paths,
  screens,
}) => {
  const dispatch = useDispatch();
  const addRule = () => {
    dispatch(addPath({ screenId }));
  };
  const sortedPath = [...paths].sort(sortByPriority);
  const usedPathIds = paths.map((p) => p.id);
  return (
    <div>
      {sortedPath.map((path) => (
        <PathEditBox
          screens={screens}
          questionId={questionId}
          screenId={screenId}
          key={path.id}
          questionType={questionType}
          availablePaths={availablePaths}
          usedPathIds={usedPathIds}
          path={path}
        />
      ))}
      <button onClick={addRule} className="btn btn-primary">
        Add Rule
      </button>
    </div>
  );
};
