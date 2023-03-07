import React from 'react';
import { useSelector } from 'react-redux';
import {
  IActivity,
  selectCurrentActivity,
} from '../../../delivery/store/features/activities/slice';
import {
  getAvailablePaths,
  getScreenPrimaryQuestion,
  getScreenQuestionType,
  questionTypeLabels,
} from './paths/path-options';
import { AllPaths } from './paths/path-types';

interface FlowchartSidebarProps {}

export const FlowchartSidebar: React.FC<FlowchartSidebarProps> = () => {
  const selected = useSelector(selectCurrentActivity);
  return (
    <div className="flowchart-sidebar">{selected && <SelectedScreen screen={selected} />}</div>
  );
};

const SelectedScreen: React.FC<{ screen: IActivity }> = ({ screen }) => {
  const primaryQuestion = getScreenPrimaryQuestion(screen);
  const questionId = primaryQuestion?.id || 'no question';
  const questionType = questionTypeLabels[getScreenQuestionType(screen)];

  return (
    <div>
      <h2>{screen.title}</h2>
      {questionType && (
        <div>
          <h3>{questionType}</h3>
        </div>
      )}

      <b>rules:</b>
      <ol>
        {screen.authoring?.flowchart?.paths.map((path: AllPaths) => (
          <li key={path.id}>
            <pre>{JSON.stringify(path, null, 2)}</pre>
          </li>
        ))}
      </ol>
      <b>possible rules:</b>
      <ol>
        {getAvailablePaths(screen).map((path: AllPaths) => (
          <li key={path.id}>
            <pre>{JSON.stringify(path, null, 2)}</pre>
          </li>
        ))}
      </ol>
    </div>
  );
};
