import { EntityId } from '@reduxjs/toolkit';
import React from 'react';
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
    </div>
  );
};
