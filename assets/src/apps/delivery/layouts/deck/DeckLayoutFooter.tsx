/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getLocalizedStateSnapshot,
  getValue,
} from '../../../../adaptivity/scripting';
import {
  selectCurrentActivityContent,
  selectCurrentActivityId,
} from '../../store/features/activities/slice';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import {
  selectCurrentFeedbacks,
  selectHistoryNavigationActivity,
  selectInitPhaseComplete,
  selectIsGoodFeedback,
  selectLastCheckResults,
  selectLastCheckTriggered,
  selectLessonEnd,
  selectNextActivityId,
  setCurrentFeedbacks,
  setIsGoodFeedback,
  setMutationTriggered,
  setNextActivityId,
} from '../../store/features/adaptivity/slice';
import {
  navigateToActivity,
  navigateToFirstActivity,
  navigateToLastActivity,
  navigateToNextActivity,
  navigateToPrevActivity,
} from '../../store/features/groups/actions/deck';
import { selectCurrentActivityTree } from '../../store/features/groups/selectors/deck';
import { selectEnableHistory, selectPageContent, setScore } from '../../store/features/page/slice';
import FeedbackRenderer from './components/FeedbackRenderer';
import HistoryNavigation from './components/HistoryNavigation';

export const handleValueExpression = (
  currentActivityTree: any[] | null,
  operationValue: string,
) => {
  let value = operationValue;
  if (typeof value === 'string' && currentActivityTree) {
    if (
      (value[0] === '{' && value[1] !== '"') ||
      (value.indexOf('{') !== -1 && value.indexOf('}') !== -1)
    ) {
      const variableList = value.match(/\{(.*?)\}/g);
      variableList?.forEach((item) => {
        if (item.indexOf('|') > 0) {
          // if the variable is already targetted to another screen, we don't need to do this.
          return;
        }
        //Need to replace the opening and closing {} else the expression will look something like q.145225454.1|{stage.input.value}
        //it should be like {q.145225454.1|stage.input.value}
        const modifiedValue = item.replace('{', '').replace('}', '');
        const lstVar = item.split('.');
        if (lstVar?.length > 2) {
          const ownerActivity = currentActivityTree?.find(
            (activity) => !!activity.content.partsLayout.find((p: any) => p.id === lstVar[1]),
          );
          //ownerActivity is undefined for app.spr.adaptivity.something i.e. Beagle app variables
          if (ownerActivity) {
            value = value.replace(`${item}`, `{${ownerActivity.id}|${modifiedValue}}`);
          }
        }
      });
    }
  }
  return value;
};
export interface NextButton {
  text: string;
  handler: () => void;
  isLoading: boolean;
  isGoodFeedbackPresent: boolean;
  currentFeedbacksCount: number;
  isFeedbackIconDisplayed: boolean;
  showCheckBtn: boolean;
}

const initialNextButtonClassName = 'checkBtn';
const wrongFeedbackNextButtonClassName = 'closeFeedbackBtn wrongFeedback';
const correctFeedbackNextButtonClassName = 'closeFeedbackBtn correctFeedback';
/* const componentEventService = ComponentEventService.getInstance(); */
const NextButton: React.FC<NextButton> = ({
  text,
  handler,
  isLoading,
  isGoodFeedbackPresent,
  currentFeedbacksCount,
  isFeedbackIconDisplayed,
  showCheckBtn,
}) => {
  const isEnd = useSelector(selectLessonEnd);
  const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
  const styles: CSSProperties = {};
  if (historyModeNavigation) {
    styles.opacity = 0.5;
    styles.cursor = 'not-allowed';
  }
  const showDisabled = historyModeNavigation ? true : isLoading;
  const showHideCheckButton =
    !showCheckBtn && !isGoodFeedbackPresent && !isFeedbackIconDisplayed ? 'hideCheckBtn' : '';

  return (
    <div
      className={`buttonContainer ${showHideCheckButton} ${
        isEnd ? 'displayNone hideCheckBtn' : ''
      }`}
    >
      <button
        onClick={handler}
        disabled={showDisabled}
        style={styles}
        className={
          isGoodFeedbackPresent
            ? correctFeedbackNextButtonClassName
            : currentFeedbacksCount > 0 && isFeedbackIconDisplayed
            ? wrongFeedbackNextButtonClassName
            : initialNextButtonClassName
        }
      >
        {isLoading ? (
          <div className="spricon-ajax-loader" style={{ backgroundPositionY: '-540px' }} />
        ) : (
          <div className="ellipsis">{text}</div>
        )}
      </button>

      {/* do we need this blocker div? */}
      {/* <div className="blocker displayNone" /> */}
    </div>
  );
};

const DeckLayoutFooter: React.FC = () => {
  const dispatch = useDispatch();

  const currentPage = useSelector(selectPageContent);
  const currentActivityId = useSelector(selectCurrentActivityId);
  const currentActivity = useSelector(selectCurrentActivityContent);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const isGoodFeedback = useSelector(selectIsGoodFeedback);
  const currentFeedbacks = useSelector(selectCurrentFeedbacks);
  const nextActivityId: string = useSelector(selectNextActivityId);
  const enableHistory = useSelector(selectEnableHistory);
  const lastCheckTimestamp = useSelector(selectLastCheckTriggered);
  const lastCheckResults = useSelector(selectLastCheckResults);
  const initPhaseComplete = useSelector(selectInitPhaseComplete);

  const [isLoading, setIsLoading] = useState(false);
  const [hasOnlyMutation, setHasOnlyMutation] = useState(false);
  const [displayFeedback, setDisplayFeedback] = useState(false);
  const [displayFeedbackHeader, setDisplayFeedbackHeader] = useState<boolean>(false);
  const [displayFeedbackIcon, setDisplayFeedbackIcon] = useState(false);
  const [nextButtonText, setNextButtonText] = useState('Next');
  const [nextCheckButtonText, setNextCheckButtonText] = useState('Next');

  useEffect(() => {
    if (!lastCheckTimestamp) {
      return;
    }
    // when this changes, notify that check has started
  }, [lastCheckTimestamp]);

  const processResults = (events: any) => {
    const actionsByType: any = {
      feedback: [],
      mutateState: [],
      navigation: [],
    };
    events.forEach((evt: any) => {
      const { actions } = evt.params;
      actions.forEach((action: any) => {
        actionsByType[action.type].push(action);
      });
    });
    return actionsByType;
  };

  const checkIfFirstEventHasNavigation = (event: any) => {
    let isDifferentNavigationExist = false;
    const { actions } = event.params;
    actions.forEach((action: any) => {
      if (action.type === 'navigation' && action.params.target !== currentActivityId) {
        isDifferentNavigationExist = true;
      }
    });
    return isDifferentNavigationExist;
  };

  useEffect(() => {
    if (!lastCheckResults || !lastCheckResults.results.length) {
      return;
    }
    // when this changes, notify check has completed

    const isCorrect = lastCheckResults.results.every((r: any) => r.params.correct);

    // depending on combineFeedback value is whether we should address more than one event
    const combineFeedback = !!currentActivity?.custom.combineFeedback;
    let eventsToProcess = [lastCheckResults.results[0]];
    if (combineFeedback) {
      //if the first event has a navigation to different screen
      // we ignore the rest of the events ang fire this one.
      const doesFirstEventHasNavigation = checkIfFirstEventHasNavigation(
        lastCheckResults.results[0],
      );
      if (doesFirstEventHasNavigation) {
        eventsToProcess = [lastCheckResults.results[0]];
      } else {
        eventsToProcess = lastCheckResults.results;
      }
    }

    const actionsByType = processResults(eventsToProcess);

    const hasFeedback = actionsByType.feedback.length > 0;
    const hasNavigation = actionsByType.navigation.length > 0;

    if (actionsByType.mutateState.length) {
      const mutationsModified = actionsByType.mutateState.map((op: any) => {
        let scopedTarget = op.params.target;

        if (scopedTarget.indexOf('stage') === 0) {
          const lstVar = scopedTarget.split('.');

          if (lstVar?.length > 1) {
            const ownerActivity = currentActivityTree?.find(
              (activity) => !!activity.content.partsLayout.find((p: any) => p.id === lstVar[1]),
            );
            scopedTarget = ownerActivity
              ? `${ownerActivity.id}|${op.params.target}`
              : `${currentActivityId}|${op.params.target}`;
          }
        }
        const globalOp: ApplyStateOperation = {
          target: scopedTarget,
          operator: op.params.operator,
          value: handleValueExpression(currentActivityTree, op.params.value),
          targetType: op.params.targetType || op.params.type,
        };
        return globalOp;
      });

      const mutateResults = bulkApplyState(mutationsModified, defaultGlobalEnv);
      // should respond to scripting errors?
      console.log('MUTATE ACTIONS', {
        mutateResults,
        mutationsModified,
        score: getValue('session.tutorialScore', defaultGlobalEnv) || 0,
      });

      const latestSnapshot = getLocalizedStateSnapshot(
        (currentActivityTree || []).map((a) => a.id),
      );
      // instead of sending the entire enapshot, taking latest values from store and sending that as mutate state in all the components
      const mutatedObjects = actionsByType.mutateState.reduce((collect: any, op: any) => {
        collect[op.params.target] = latestSnapshot[op.params.target];
        return collect;
      }, {});

      dispatch(
        setMutationTriggered({
          changes: mutatedObjects,
        }),
      );
    }

    // after any mutations applied, and just in case
    const tutScore = getValue('session.tutorialScore', defaultGlobalEnv) || 0;
    const curScore = getValue('session.currentQuestionScore', defaultGlobalEnv) || 0;
    dispatch(setScore({ score: tutScore + curScore }));

    if (hasFeedback) {
      dispatch(
        setCurrentFeedbacks({
          feedbacks: actionsByType.feedback.map((fAction: any) => fAction.params.feedback),
        }),
      );
      dispatch(setIsGoodFeedback({ isGood: isCorrect }));
      // need to queue up the feedback display prior to nav
      // there are cases when wrong trap state gets trigger but user is still allowed to jump to another activity
      if (hasNavigation) {
        const [firstNavAction] = actionsByType.navigation;
        const navTarget = firstNavAction.params.target;
        dispatch(setNextActivityId({ activityId: navTarget }));
      }
    } else {
      if (hasNavigation) {
        const [firstNavAction] = actionsByType.navigation;
        const navTarget = firstNavAction.params.target;
        switch (navTarget) {
          case 'next':
            dispatch(navigateToNextActivity());
            break;
          case 'prev':
            dispatch(navigateToPrevActivity());
            break;
          case 'first':
            dispatch(navigateToFirstActivity());
            break;
          case 'last':
            dispatch(navigateToLastActivity());
            break;
          default:
            // assume it's a sequenceId
            dispatch(navigateToActivity(navTarget));
        }
      }
    }

    if (!hasFeedback && !hasNavigation) {
      setHasOnlyMutation(true);
    }
  }, [lastCheckResults]);

  const checkHandler = () => {
    setIsLoading(true);
    if (displayFeedback) setDisplayFeedback(false);

    // if (isGoodFeedback && canProceed) {
    if (isGoodFeedback) {
      if (nextActivityId && nextActivityId.trim()) {
        dispatch(
          nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
        );
      } else {
        // if there is no navigation, then keep checking
        dispatch(triggerCheck({ activityId: currentActivity?.id }));
      }
      dispatch(setIsGoodFeedback({ isGood: false }));
      dispatch(setNextActivityId({ nextActivityId: '' }));
      setIsLoading(false);
    } else if (
      (!isLegacyTheme || !currentActivity?.custom?.showCheckBtn) &&
      !isGoodFeedback &&
      currentFeedbacks?.length > 0 &&
      displayFeedbackIcon
    ) {
      if (currentPage.custom?.advancedAuthoring && !enableHistory) {
        dispatch(triggerCheck({ activityId: currentActivity?.id }));
      } else if (
        !isGoodFeedback &&
        nextActivityId?.trim().length &&
        nextActivityId !== currentActivityId
      ) {
        //** there are cases when wrong trap state gets trigger but user is still allowed to jump to another activity */
        //** if we don't do this then, every time Next button will trigger a check events instead of navigating user to respective activity */
        dispatch(
          nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
        );
        dispatch(setNextActivityId({ nextActivityId: '' }));
      } else {
        dispatch(setIsGoodFeedback({ isGoodFeedback: false }));
        setDisplayFeedbackIcon(false);
        setIsLoading(false);
        setDisplayFeedback(false);
        setNextButtonText(nextCheckButtonText);
      }
    } else if (
      !isGoodFeedback &&
      nextActivityId?.trim().length &&
      nextActivityId !== currentActivityId
    ) {
      //** DT - there are cases when wrong trap state gets trigger but user is still allowed to jump to another activity */
      //** if we don't do this then, every time Next button will trigger a check events instead of navigating user to respective activity */
      dispatch(
        nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
      );
      dispatch(setNextActivityId({ nextActivityId: '' }));
    } else {
      dispatch(triggerCheck({ activityId: currentActivityId as string }));
    }
  };

  const lastCheckTriggered = useSelector(selectLastCheckTriggered);
  const [checkInProgress, setCheckInProgress] = useState(false);

  useEffect(() => {
    if (!lastCheckTriggered) {
      return;
    }
    setCheckInProgress(true);
    setIsLoading(true);
  }, [lastCheckTriggered]);

  useEffect(() => {
    if (hasOnlyMutation) {
      setIsLoading(false);
      setHasOnlyMutation(false);
    }
  }, [hasOnlyMutation]);

  useEffect(() => {
    if (checkInProgress && lastCheckResults) {
      setCheckInProgress(false);
    }
  }, [checkInProgress, lastCheckResults]);

  const checkFeedbackHandler = () => {
    // right now just nav w/o checking
    setDisplayFeedback(!displayFeedback);
  };

  const closeFeedbackHandler = () => {
    // right now just nav w/o checking
    setDisplayFeedback(false);
  };

  const updateButtontext = () => {
    let text = currentActivity?.custom?.mainBtnLabel || 'Next';
    if (currentFeedbacks && currentFeedbacks.length) {
      const lastFeedback = currentFeedbacks[currentFeedbacks.length - 1];
      text = lastFeedback.custom?.mainBtnLabel || 'Next';
    }
    setNextButtonText(text);
  };

  const isLegacyTheme = currentPage?.custom?.themeId;
  // TODO: global const for default width magic number?
  const containerWidth =
    currentActivity?.custom?.width || currentPage?.custom?.defaultScreenWidth || 1100;

  const containerClasses = ['checkContainer', 'rowRestriction', 'columnRestriction'];

  // effects
  useEffect(() => {
    // legacy usage expects the feedback header to be handled
    // programatically based on the page themeId
    setDisplayFeedbackHeader(!!currentPage?.custom?.themeId);
  }, [currentPage]);

  useEffect(() => {
    setIsLoading(false);
    if (currentFeedbacks.length > 0) {
      setDisplayFeedbackIcon(true);
      setDisplayFeedback(true);
      updateButtontext();
    } else {
      setDisplayFeedbackIcon(false);
      setDisplayFeedback(false);
    }
  }, [currentFeedbacks]);

  useEffect(() => {
    const buttonText = currentActivity?.custom?.checkButtonLabel
      ? currentActivity.custom.checkButtonLabel
      : 'Next';
    setNextCheckButtonText(buttonText);
    setDisplayFeedbackIcon(false);
    setDisplayFeedback(false);
    setNextButtonText(buttonText);
    setIsLoading(false);
  }, [currentActivity]);

  const currentActivityIds = (currentActivityTree || []).map((a) => a.id);
  return (
    <div className={containerClasses.join(' ')} style={{ width: containerWidth }}>
      <NextButton
        isLoading={isLoading || !initPhaseComplete}
        text={nextButtonText}
        handler={checkHandler}
        isGoodFeedbackPresent={isGoodFeedback}
        currentFeedbacksCount={currentFeedbacks.length}
        isFeedbackIconDisplayed={displayFeedbackIcon}
        showCheckBtn={currentActivity?.custom?.showCheckBtn}
      />
      <div className="feedbackContainer rowRestriction" style={{ top: 525 }}>
        <div className={`bottomContainer fixed ${!displayFeedback ? 'minimized' : ''}`}>
          <button
            onClick={checkFeedbackHandler}
            className={displayFeedbackIcon ? 'toggleFeedbackBtn' : 'toggleFeedbackBtn displayNone'}
            title="Toggle feedback visibility"
            aria-label="Show feedback"
            aria-haspopup="true"
            aria-controls="stage-feedback"
            aria-pressed="false"
          >
            <div className="icon" />
          </button>
          <div
            id="stage-feedback"
            className={displayFeedback ? '' : 'displayNone'}
            role="alertdialog"
            aria-live="polite"
            aria-hidden="true"
            aria-label="Feedback dialog"
          >
            <div className={`theme-feedback-header ${!displayFeedbackHeader ? 'displayNone' : ''}`}>
              <button
                onClick={closeFeedbackHandler}
                className="theme-feedback-header__close-btn"
                aria-label="Minimize feedback"
              >
                <span>
                  <div className="theme-feedback-header__close-icon" />
                </span>
              </button>
            </div>
            <style type="text/css" aria-hidden="true" />
            <div className="content" style={{ overflow: 'hidden auto !important' }}>
              {/* TODO: snapshot method causes constant re-render (props change) */}
              <FeedbackRenderer
                feedbacks={currentFeedbacks}
                snapshot={getLocalizedStateSnapshot(currentActivityIds)}
              />
            </div>
            {/* <button className="showSolnBtn showSolution displayNone">
                            <div className="ellipsis">Show solution</div>
                        </button> */}
          </div>
        </div>
      </div>
      <HistoryNavigation />
    </div>
  );
};

export default DeckLayoutFooter;
