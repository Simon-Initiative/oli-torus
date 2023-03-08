import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivity,
} from '../../../../delivery/store/features/activities/slice';
import {
  getAvailablePaths,
  getScreenPrimaryQuestion,
  getScreenQuestionType,
  questionTypeLabels,
} from '../paths/path-options';

import { PathsEditor } from './PathsEditor';

interface FlowchartSidebarProps {}

export const FlowchartSidebar: React.FC<FlowchartSidebarProps> = () => {
  const selected = useSelector(selectCurrentActivity);
  return (
    <div className="flowchart-sidebar">{selected && <SelectedScreen screen={selected} />}</div>
  );
};

const SelectedScreen: React.FC<{ screen: IActivity }> = ({ screen }) => {
  const primaryQuestion = getScreenPrimaryQuestion(screen);
  const questionType = questionTypeLabels[getScreenQuestionType(screen)];
  const activities = useSelector(selectAllActivities);

  const screens: Record<string, string> = useMemo(() => {
    return activities.reduce((acc, activity) => {
      return {
        ...acc,
        [activity.id]: activity.title || 'Untitled',
      };
    }, {} as Record<string, string>);
  }, [activities]);

  return (
    <div>
      <h2>{screen.title}</h2>
      {primaryQuestion && questionType && (
        <div>
          <h3>{questionType}</h3>
        </div>
      )}

      <PathsEditor
        screens={screens}
        questionId={primaryQuestion?.id || ''}
        screenId={screen.id}
        screenTitle={screen.title || 'Screen'}
        questionType={questionType}
        availablePaths={getAvailablePaths(screen)}
        paths={screen.authoring?.flowchart?.paths || []}
      />
    </div>
  );
};
