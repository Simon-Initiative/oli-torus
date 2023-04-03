import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import {
  getAvailablePaths,
  getScreenPrimaryQuestion,
  getScreenQuestionType,
  questionTypeLabels,
} from '../paths/path-options';
import { validateScreen } from '../screens/screen-validation';

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
  const sequence = useSelector(selectSequence);
  const validations = validateScreen(screen, activities, sequence);

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

      {validations.map((err, index) => (
        <ValidationError key={index}>{err}</ValidationError>
      ))}

      {screen.authoring?.flowchart?.screenType !== 'end_screen' && (
        <PathsEditor
          screens={screens}
          questionId={primaryQuestion?.id || ''}
          screenId={screen.id}
          questionType={questionType}
          availablePaths={getAvailablePaths(screen)}
          paths={screen.authoring?.flowchart?.paths || []}
        />
      )}
    </div>
  );
};

const ValidationError: React.FC = ({ children }) => {
  return <div className="validation-error">{children}</div>;
};
