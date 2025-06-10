import React, { CSSProperties, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { applyState, templatizeText } from 'adaptivity/scripting';
import { savePartState } from 'apps/delivery/store/features/attempt/actions/savePart';
import { updateGlobalUserState } from 'data/persistence/extrinsic';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getEnvState,
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
  finalizeLesson,
  navigateToActivity,
  navigateToFirstActivity,
  navigateToLastActivity,
  navigateToNextActivity,
  navigateToPrevActivity,
} from '../../store/features/groups/actions/deck';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
} from '../../store/features/groups/selectors/deck';
import {
  selectIsLegacyTheme,
  selectPageContent,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectReviewMode,
  selectSectionSlug,
  selectBlobStorageProvider,
  setScore,
  setScreenIdleExpirationTime,
} from '../../store/features/page/slice';
import EverappContainer from './components/EverappContainer';
import FeedbackContainer from './components/FeedbackContainer';
import HistoryNavigation from './components/HistoryNavigation';

export const handleValueExpression = (
  currentActivityTree: any[] | null,
  operationValue: string,
  operator?: string,
) => {
  let value = operationValue;
  if (typeof value === 'string' && currentActivityTree) {
    if (
      (value[0] === '{' && value[1] !== '"') ||
      (value.indexOf('{') !== -1 && value.indexOf('}') !== -1)
    ) {
      const variableList = value.match(/\{(.*?)\}/g);
      variableList?.forEach((item) => {
        // if the variable is already targetted to another screen, we just want to make sure that the actual owner Id is used in expression.
        if (item.indexOf('|') > 0) {
          //Need to replace the opening and closing {} else the expression will look something like q.145225454.1|{stage.input.value}
          //it should be like {q.145225454.1|stage.input.value}
          const modifiedValue = item;
          const modifiedItem = modifiedValue.split('|');
          const partVariable = modifiedItem[1];
          const variableSplitter = modifiedValue.indexOf('|');
          // an expression might be like {round(({q.145225454.1|stage.input.value})/10)*10}, so we just want to replace the {q.145225454.1|stage.input.value}
          // so getting the sequenceId and parts that will be used later to replace the value
          const sequenceId = modifiedValue.substring(
            modifiedItem[0].lastIndexOf('{'),
            variableSplitter + 1,
          );
          const parts = modifiedItem[1].substring(0, modifiedItem[1].indexOf('}') + 1);
          const variables = partVariable.split('.');
          const ownerActivity = currentActivityTree?.find(
            (activity) => !!activity.content.partsLayout.find((p: any) => p.id === variables[1]),
          );
          //ownerActivity is undefined for app.spr.adaptivity.something i.e. Beagle app variables
          if (ownerActivity) {
            value = value.replace(
              `${sequenceId}|${parts}`,
              `{${ownerActivity.id}|${partVariable}}`,
            );
          }
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
    } else if (operator === 'bind to') {
      const variables = value.split('.');
      const ownerActivity = currentActivityTree?.find(
        (activity) => !!activity.content.partsLayout.find((p: any) => p.id === variables[1]),
      );
      //ownerActivity is undefined for app.spr.adaptivity.something i.e. Beagle app variables
      if (ownerActivity) {
        value = `${ownerActivity.id}|${value}`;
      }
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
  const reviewMode = useSelector(selectReviewMode);
  const styles: CSSProperties = {};
  if (historyModeNavigation || reviewMode) {
    styles.opacity = 0.5;
    styles.cursor = 'not-allowed';
  }
  const showDisabled = historyModeNavigation || reviewMode ? true : isLoading;
  let showHideCheckButton =
    !showCheckBtn && !isGoodFeedbackPresent && !isFeedbackIconDisplayed ? 'hideCheckBtn' : '';

  showHideCheckButton =
    showHideCheckButton === 'hideCheckBtn' && reviewMode ? '' : showHideCheckButton;
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

export const processResults = (events: any) => {
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

export const checkIfFirstEventHasNavigation = (event: any) => {
  let isDifferentNavigationExist = false;
  const { actions } = event.params;
  actions.forEach((action: any) => {
    if (action.type === 'navigation') {
      isDifferentNavigationExist = true;
    }
  });
  return isDifferentNavigationExist;
};

const DeckLayoutFooter: React.FC = () => {
  const dispatch = useDispatch();
  const reviewMode = useSelector(selectReviewMode);
  const currentPage = useSelector(selectPageContent);
  const currentActivityId = useSelector(selectCurrentActivityId);
  const currentActivity = useSelector(selectCurrentActivityContent);
  const currentActivityTree = useSelector(selectCurrentActivityTree);
  const isGoodFeedback = useSelector(selectIsGoodFeedback);
  const currentFeedbacks = useSelector(selectCurrentFeedbacks);
  const nextActivityId: string = useSelector(selectNextActivityId);
  const blobStorageProvider = useSelector(selectBlobStorageProvider);
  const lastCheckTimestamp = useSelector(selectLastCheckTriggered);
  const lastCheckResults = useSelector(selectLastCheckResults);
  const initPhaseComplete = useSelector(selectInitPhaseComplete);
  const currentActivityAttemptTree = useSelector(selectCurrentActivityTreeAttemptState);
  const isPreviewMode = useSelector(selectPreviewMode);
  const [isLoading, setIsLoading] = useState(false);
  const [hasOnlyMutation, setHasOnlyMutation] = useState(false);
  const [displayFeedback, setDisplayFeedback] = useState(false);
  const [displayFeedbackHeader, setDisplayFeedbackHeader] = useState<boolean>(false);
  const [displayFeedbackIcon, setDisplayFeedbackIcon] = useState(false);
  const [nextButtonText, setNextButtonText] = useState('Next');
  const [nextCheckButtonText, setNextCheckButtonText] = useState('Next');
  const [solutionButtonText, setSolutionButtonText] = useState('Show Solution');
  const [displaySolutionButton, setDisplaySolutionButton] = useState(false);
  const sectionSlug = useSelector(selectSectionSlug);
  const resourceAttemptGuid = useSelector(selectResourceAttemptGuid);

  useEffect(() => {
    if (!lastCheckTimestamp) {
      return;
    }
    // when this changes, notify that check has started
  }, [lastCheckTimestamp]);

  const checkIfAllEventsHaveSameNavigation = (results: any) => {
    const navigationTargets: string[] = [];
    const resultHavingNavigation = results.filter((result: any) => {
      const { actions } = result.params;
      let hasNavigation = false;
      actions.forEach((action: any) => {
        if (action.type === 'navigation') {
          if (!navigationTargets.includes(action.params.target)) {
            navigationTargets.push(action.params.target);
          }
          hasNavigation = true;
        }
      });
      return hasNavigation;
    });
    return resultHavingNavigation.length === results.length && navigationTargets.length === 1;
  };

  const saveMutateStateValuesToServer = (mutations: any) => {
    const activityAttemptTree = currentActivityAttemptTree;
    const currentAttempt: any = activityAttemptTree
      ? activityAttemptTree[activityAttemptTree.length - 1]
      : null;

    const currentActivity: any = currentActivityTree
      ? currentActivityTree[currentActivityTree?.length - 1]
      : null;
    const currentActivityAttemptGuid = currentActivity?.attemptGuid;
    if (!currentAttempt || !currentActivityAttemptGuid) {
      return;
    }
    mutations.forEach((op: any) => {
      let scopedTarget = op.params.target;
      if (scopedTarget.indexOf('stage') === 0) {
        const lstVar = scopedTarget.split('.');
        if (lstVar?.length > 1) {
          const partId = lstVar[1];
          const partKey = lstVar[2];
          let partAttemptGuid = '';
          const partAttempt = currentAttempt?.parts.filter(
            (attempt: any) => attempt.partId == partId,
          );
          if (partAttempt?.length) {
            const ownerActivity = currentActivityTree?.find(
              (activity) =>
                !!(activity.content?.partsLayout || []).find((p: any) => p.id === lstVar[1]),
            );
            scopedTarget = ownerActivity
              ? `${ownerActivity.id}|${op.params.target}`
              : `${currentActivityId}|${op.params.target}`;

            partAttemptGuid = partAttempt[0].attemptGuid;
            const response: any = [
              {
                id: op.params.target,
                key: partKey,
                type: op.params.targetType || op.params.type,
                value: getValue(`${scopedTarget}`, defaultGlobalEnv),
                path: scopedTarget,
              },
            ];
            const responseMap = response.reduce(
              (result: { [x: string]: any }, item: { key: string; path: string }) => {
                result[item.key] = { ...item };
                return result;
              },
              {},
            );
            dispatch(
              savePartState({
                attemptGuid: currentActivityAttemptGuid,
                partAttemptGuid,
                response: responseMap,
              }),
            );
          }
        }
      }
    });

    //when lesson 'variables' were getting update via mutate state, we were not sending the updated values to server
    // the previous savePartState code (line 326) was only sending the parts variable to the server which starts from 'stage.something.value' etc.
    // we need to update the extrinsic  Snapshot to server
    const latestSnapshot = getLocalizedStateSnapshot((currentActivityTree || []).map((a) => a.id));
    const extrinsicSnapshot = Object.keys(latestSnapshot).reduce(
      (acc: Record<string, any>, key) => {
        const isSessionVariable = key.startsWith('session.');
        const isVarVariable = key.startsWith('variables.');
        const isEverAppVariable = key.startsWith('app.');
        if (isSessionVariable || isVarVariable || isEverAppVariable) {
          acc[key] = latestSnapshot[key];
        }
        return acc;
      },
      {},
    );
    writePageAttemptState(blobStorageProvider, sectionSlug, resourceAttemptGuid, extrinsicSnapshot);
  };

  useEffect(() => {
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
    if (!lastCheckResults || !lastCheckResults.results.length) {
      return;
    }
    // when this changes, notify check has completed

    const isCorrect = lastCheckResults.results.every((r: any) => r.params.correct);

    // depending on combineFeedback value is whether we should address more than one event
    const combineFeedback = !!currentActivity?.custom.combineFeedback;
    let eventsToProcess = [lastCheckResults.results[0]];
    let doesFirstEventHasNavigation = false;
    let doesAllEventsHaveSameNavigation = false;
    if (combineFeedback) {
      //if the first event has a navigation to different screen
      // we ignore the rest of the events and fire this one.
      doesAllEventsHaveSameNavigation = checkIfAllEventsHaveSameNavigation(
        lastCheckResults.results,
      );
      if (doesAllEventsHaveSameNavigation) {
        eventsToProcess = lastCheckResults.results;
      } else {
        doesFirstEventHasNavigation = checkIfFirstEventHasNavigation(lastCheckResults.results[0]);
        // if all the rules are correct, we process all the events because we want to display all the correct feedbacks
        if (doesFirstEventHasNavigation && !isCorrect) {
          eventsToProcess = [lastCheckResults.results[0]];
        } else {
          eventsToProcess = lastCheckResults.results;
        }
      }
    }
    const actionsByType = processResults(eventsToProcess);

    const hasFeedback = actionsByType.feedback.length > 0;
    const hasNavigation = actionsByType.navigation.length > 0;

    if (actionsByType.mutateState.length) {
      //Need to filter 'session.currentQuestionScore' mutation because we are already performed all the scoring logic in rules engine
      const mutations = actionsByType.mutateState.filter(
        (action: any) => action.params.target !== 'session.currentQuestionScore',
      );
      const mutationsModified = mutations.map((op: any) => {
        let scopedTarget = op.params.target;

        if (scopedTarget.indexOf('stage') === 0) {
          const lstVar = scopedTarget.split('.');

          if (lstVar?.length > 1) {
            const ownerActivity = currentActivityTree?.find(
              (activity) =>
                !!(activity.content?.partsLayout || []).find((p: any) => p.id === lstVar[1]),
            );
            scopedTarget = ownerActivity
              ? `${ownerActivity.id}|${op.params.target}`
              : `${currentActivityId}|${op.params.target}`;
          }
        }
        const globalOp: ApplyStateOperation = {
          target: scopedTarget,
          operator: op.params.operator,
          value: handleValueExpression(currentActivityTree, op.params.value, op.params.operator),
          targetType: op.params.targetType || op.params.type,
        };
        return globalOp;
      });

      const _mutateResults = bulkApplyState(mutationsModified, defaultGlobalEnv);
      if (!isPreviewMode) {
        saveMutateStateValuesToServer(mutations);
      }
      // should respond to scripting errors?
      /* console.log('MUTATE ACTIONS', {
        mutateResults,
        mutationsModified,
        score: getValue('session.tutorialScore', defaultGlobalEnv) || 0,
      }); */

      const everAppUpdates = mutationsModified.filter((op: ApplyStateOperation) => {
        return op.target.indexOf('app') === 0;
      });
      if (everAppUpdates.length) {
        const envState = getEnvState(defaultGlobalEnv);
        const everAppState = everAppUpdates.reduce((acc: any, op: ApplyStateOperation) => {
          const [, everAppId] = op.target.split('.');
          acc[everAppId] = acc[everAppId] || {};
          acc[everAppId][op.target.replace(`app.${everAppId}.`, '')] = envState[op.target];
          return acc;
        }, {});
        updateGlobalUserState(blobStorageProvider, everAppState, isPreviewMode);
      }

      const latestSnapshot = getLocalizedStateSnapshot(
        (currentActivityTree || []).map((a) => a.id),
      );
      // instead of sending the entire enapshot, taking latest values from store and sending that as mutate state in all the components
      const mutatedObjects = mutations.reduce((collect: any, op: any) => {
        let target = op.params.target;
        if (target.indexOf('stage') === 0) {
          const lstVar = op.params.target.split('.');
          if (lstVar?.length > 1) {
            const ownerActivity = currentActivityTree?.find(
              (activity) =>
                !!(activity.content?.partsLayout || []).find((p: any) => p.id === lstVar[1]),
            );
            target = ownerActivity
              ? `${ownerActivity.id}|${op.params.target}`
              : `${op.params.target}`;
          }
        }
        const originalValue = latestSnapshot[target];
        const typeOfOriginalValue = typeof originalValue;
        const evaluatedValue =
          typeOfOriginalValue === 'string'
            ? templatizeText(originalValue, latestSnapshot, defaultGlobalEnv, true)
            : originalValue;
        collect[op.params.target] = evaluatedValue;
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
          case 'endOfLesson':
            dispatch(finalizeLesson());
            break;
          default:
            if (doesFirstEventHasNavigation && combineFeedback && navTarget === currentActivityId) {
              const updateAttempt: ApplyStateOperation[] = [
                {
                  target: 'session.attemptNumber',
                  operator: '=',
                  value: 1,
                },
                {
                  target: `${navTarget}|session.attemptNumber`,
                  operator: '=',
                  value: 1,
                },
              ];
              bulkApplyState(updateAttempt, defaultGlobalEnv);
              setHasOnlyMutation(true);
            }
            // assume it's a sequenceId
            dispatch(navigateToActivity(navTarget));
        }
      }
    }

    if (!hasFeedback && !hasNavigation) {
      setHasOnlyMutation(true);
    }
  }, [lastCheckResults, isPreviewMode]);

  const updateActivityHistoryTimeStamp = () => {
    //If we get correct Feedback on current screen, on 'Next' button click, we would navigated to next screen
    // however, instead if we navigate back using the 'History' button and then come back to current screen (i.e. where we got the good feedback earlier).
    //At this point, session.visitTimestamps.${currentActivity?.id} get set to 0 because we are revisting the screen.
    //We update the timestamp on Trigger Check however Since clicking the 'Next' button takes user to next screen, the timestamp of current screen
    //never gets  updated and is always set to 0 hence it's always visible on top of the history list.
    // Here we are checking, when we user leaves the screen, if the visit timestamp is zero then lets update the timestamp
    const targetVisitTimeStampOp: ApplyStateOperation = {
      target: `session.visitTimestamps.${currentActivityId}`,
      operator: '=',
      value: Date.now(),
    };
    applyState(targetVisitTimeStampOp, defaultGlobalEnv);
  };

  const checkHandler = () => {
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
    setIsLoading(true);
    /* console.log('CHECK BUTTON CLICKED', {
      isGoodFeedback,
      displayFeedback,
      nextActivityId,
      isLegacyTheme,
      currentActivity,
      displayFeedbackIcon,
    }); */
    const activityHistoryTimeStamp = getValue(
      `session.visitTimestamps.${currentActivityId}`,
      defaultGlobalEnv,
    );
    const targetIsResumeModeOp: ApplyStateOperation = {
      target: 'session.isResumeMode',
      operator: '=',
      value: false,
    };
    applyState(targetIsResumeModeOp, defaultGlobalEnv);

    if (displayFeedback) setDisplayFeedback(false);

    // if (isGoodFeedback && canProceed) {
    if (isGoodFeedback) {
      if (activityHistoryTimeStamp === 0) {
        updateActivityHistoryTimeStamp();
      }
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
      if (
        !isGoodFeedback &&
        nextActivityId?.trim().length &&
        nextActivityId !== currentActivityId
      ) {
        if (activityHistoryTimeStamp === 0) {
          updateActivityHistoryTimeStamp();
        }
        //** there are cases when wrong trap state gets trigger but user is still allowed to jump to another activity  */
        //** if we don't do this then, every time Next button will trigger a check events instead of navigating user to respective activity */
        dispatch(
          nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
        );
        dispatch(setNextActivityId({ nextActivityId: '' }));
      } else if (!currentActivity?.custom?.showCheckBtn) {
        dispatch(triggerCheck({ activityId: currentActivity?.id }));
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
      if (activityHistoryTimeStamp === 0) {
        updateActivityHistoryTimeStamp();
      }
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

  const updateButtontext = () => {
    let text = currentActivity?.custom?.mainBtnLabel || 'Next';
    if (currentFeedbacks && currentFeedbacks.length) {
      const lastFeedback = currentFeedbacks[currentFeedbacks.length - 1];
      text = lastFeedback.custom?.mainBtnLabel || 'Next';
      setSolutionButtonText(lastFeedback.custom?.applyBtnLabel || 'Show Solution');
      setDisplaySolutionButton(lastFeedback.custom?.applyBtnFlag);
    }
    setNextButtonText(text);
  };

  const isLegacyTheme = useSelector(selectIsLegacyTheme);

  // TODO: global const for default width magic number?
  const containerWidth =
    currentActivity?.custom?.width || currentPage?.custom?.defaultScreenWidth || 1100;

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

  return (
    <>
      {!reviewMode && (
        <div
          className={`checkContainer rowRestriction columnRestriction`}
          style={{ width: containerWidth, display: reviewMode ? 'block' : '' }}
        >
          <NextButton
            isLoading={isLoading || !initPhaseComplete}
            text={nextButtonText}
            handler={checkHandler}
            isGoodFeedbackPresent={isGoodFeedback}
            currentFeedbacksCount={currentFeedbacks.length}
            isFeedbackIconDisplayed={displayFeedbackIcon}
            showCheckBtn={currentActivity?.custom?.showCheckBtn}
          />
          {displaySolutionButton && (
            <button className="showSolnBtn showSolution">
              <div className="ellipsis">{solutionButtonText}</div>
            </button>
          )}
          {!isLegacyTheme && (
            <FeedbackContainer
              minimized={!displayFeedback}
              showIcon={displayFeedbackIcon}
              showHeader={displayFeedbackHeader}
              onMinimize={() => setDisplayFeedback(false)}
              onMaximize={() => setDisplayFeedback(true)}
              feedbacks={currentFeedbacks}
            />
          )}
          <HistoryNavigation />
        </div>
      )}
      {!reviewMode && isLegacyTheme && (
        <>
          <FeedbackContainer
            minimized={!displayFeedback}
            showIcon={displayFeedbackIcon}
            showHeader={displayFeedbackHeader}
            onMinimize={() => setDisplayFeedback(false)}
            onMaximize={() => setDisplayFeedback(true)}
            feedbacks={currentFeedbacks}
            style={{ width: containerWidth }}
          />
        </>
      )}
      <EverappContainer apps={currentPage?.custom?.everApps || []} />
    </>
  );
};

export default DeckLayoutFooter;
