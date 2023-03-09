import { EntityId } from '@reduxjs/toolkit';
import React from 'react';
import { useDispatch } from 'react-redux';
import { addPath } from '../flowchart-actions/add-path';
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
  const dispatch = useDispatch();
  const addRule = () => {
    dispatch(addPath({ screenId }));
  };
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
      <button onClick={addRule} className="btn btn-primary">
        Add Rule
      </button>
    </div>
  );
};
