import React from 'react';
import { EntityId } from '@reduxjs/toolkit';
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
  screenType?: string;
}

export const PathsEditor: React.FC<Props> = ({
  screenId,
  questionId,
  questionType,
  availablePaths,
  paths,
  screens,
  screenType,
}) => {
  const sortedPath = [...paths].sort(sortByPriority);
  const usedPathIds = paths.map((p) => p.id);
  return (
    <div>
      {sortedPath.map((path, index) => (
        <PathEditBox
          screens={screens}
          questionId={questionId}
          screenId={screenId}
          key={path.id + String(index)}
          questionType={questionType}
          availablePaths={availablePaths}
          usedPathIds={usedPathIds}
          path={path}
          screenType={screenType}
        />
      ))}
    </div>
  );
};
