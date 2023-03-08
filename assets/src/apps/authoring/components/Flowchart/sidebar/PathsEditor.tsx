import { EntityId } from '@reduxjs/toolkit';
import React from 'react';
import { AllPaths } from '../paths/path-types';
import { PathEditBox } from './PathEditor';

interface Props {
  questionType: string;
  availablePaths: AllPaths[];
  paths: AllPaths[];
  screenId: EntityId;
  screenTitle: string;
  questionId: string | null;
  screens: Record<string, string>;
}

export const PathsEditor: React.FC<Props> = ({
  screenTitle,
  screenId,
  questionId,
  questionType,
  availablePaths,
  paths,
  screens,
}) => {
  return (
    <div>
      {paths.map((path, index) => (
        <PathEditBox
          screens={screens}
          questionId={questionId}
          screenId={screenId}
          screenTitle={screenTitle}
          key={path.id}
          questionType={questionType}
          availablePaths={availablePaths}
          path={path}
        />
      ))}
    </div>
  );
};
