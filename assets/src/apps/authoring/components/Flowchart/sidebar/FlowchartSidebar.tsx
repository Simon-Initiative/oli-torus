import React, { useCallback, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  IActivity,
  selectAllActivities,
  selectCurrentActivity,
  setCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { ScreenButton } from '../chart-components/ScreenButton';
import { addPath } from '../flowchart-actions/add-path';
import { changeTitle } from '../flowchart-actions/change-title';
import {
  QuestionType,
  QuestionTypeMapping,
  getAvailablePaths,
  getScreenPrimaryQuestion,
  getScreenQuestionType,
  questionTypeLabels,
} from '../paths/path-options';
import { validateScreen } from '../screens/screen-validation';
import { CloseIcon } from './CloseIcon';
import { InfoIcon } from './InfoIcon';
import { PathsEditor } from './PathsEditor';
import ScreenTitle from './ScreenTitle';

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
  const questionType: QuestionType = getScreenQuestionType(screen);
  const questionTypeLabel = questionTypeLabels[questionType];
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

  const addRule = () => {
    dispatch(addPath({ screenId: screen.id }));
  };

  const paths = screen.authoring?.flowchart?.paths || [];
  const screenType = screen.authoring?.flowchart?.screenType || 'none';
  const addPathDisabled =
    screenType === QuestionTypeMapping.HUB_SPOKE || (questionType === 'none' && paths.length > 0);

  return (
    <>
      <h2 className="edit-logic-header">
        Edit logic for
        <ScreenButton onClick={onDeselectScreen} tooltip="Deselect screen">
          <CloseIcon />
        </ScreenButton>
      </h2>

      <ScreenTitle
        key={screen.id}
        screenType={screen.authoring?.flowchart?.screenType}
        title={screen.title || 'Untitled'}
        validated={validations.length === 0}
        onChange={onChangeTitle}
      />

      <div className="sidebar-scroller">
        {validations}

        {screen.authoring?.flowchart?.screenType !== 'end_screen' && (
          <PathsEditor
            screens={screens}
            questionId={primaryQuestion?.id || ''}
            screenId={screen.id}
            screenType={screen.authoring?.flowchart?.screenType}
            questionType={questionTypeLabel}
            availablePaths={getAvailablePaths(screen)}
            paths={paths}
          />
        )}
      </div>

      <button
        disabled={addPathDisabled}
        onClick={addRule}
        className="btn btn-primary flowchart-sidebar-button"
      >
        Add Rule
      </button>
    </>
  );
};
