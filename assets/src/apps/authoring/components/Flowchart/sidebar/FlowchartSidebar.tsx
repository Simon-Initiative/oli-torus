import React, { useCallback, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivity,
  setCurrentActivityId,
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
import { ScreenButton } from '../chart-components/ScreenButton';
import ScreenTitle from './ScreenTitle';
import { changeTitle } from '../flowchart-actions/change-title';
import { CloseIcon } from './CloseIcon';
import { InfoIcon } from './InfoIcon';

interface FlowchartSidebarProps {}

export const FlowchartSidebar: React.FC<FlowchartSidebarProps> = () => {
  const selected = useSelector(selectCurrentActivity);
  return (
    <div className="flowchart-sidebar">
      {selected && <SelectedScreen screen={selected} />}
      {!!selected || (
        <div className="none-selected">
          <InfoIcon />
          <span>
            Please <b>select screen</b> to build the logic between screens.
          </span>
        </div>
      )}
    </div>
  );
};

const SelectedScreen: React.FC<{ screen: IActivity }> = ({ screen }) => {
  const primaryQuestion = getScreenPrimaryQuestion(screen);
  const questionType = questionTypeLabels[getScreenQuestionType(screen)];
  const activities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);
  const validations = validateScreen(screen, activities, sequence);
  const dispatch = useDispatch();

  const onChangeTitle = useCallback(
    (newTitle) => {
      dispatch(changeTitle({ screenId: screen.id, newTitle }));
    },
    [dispatch, screen.id],
  );

  const onDeselectScreen = useCallback(() => {
    dispatch(setCurrentActivityId({ activityId: null }));
  }, [dispatch]);

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
      <h2 className="edit-logic-header">
        Edit logic for
        <ScreenButton onClick={onDeselectScreen} tooltip="Deselect screen">
          <CloseIcon />
        </ScreenButton>
      </h2>

      <ScreenTitle
        screenType={screen.authoring?.flowchart?.screenType}
        title={screen.title || 'Untitled'}
        validated={validations.length === 0}
        onChange={onChangeTitle}
      />

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
