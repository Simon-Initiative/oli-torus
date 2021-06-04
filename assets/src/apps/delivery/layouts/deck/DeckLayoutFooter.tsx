/* eslint-disable react/prop-types */
import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getLocalizedStateSnapshot,
} from '../../../../adaptivity/scripting';
import {
  selectCurrentActivityContent,
  selectCurrentActivityId,
} from '../../store/features/activities/slice';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import {
  selectCurrentFeedbacks,
  selectLessonEnd,
  selectIsGoodFeedback,
  selectLastCheckResults,
  selectLastCheckTriggered,
  selectNextActivityId,
  setCurrentFeedbacks,
  setIsGoodFeedback,
  setNextActivityId,
  setMutationTriggered,
} from '../../store/features/adaptivity/slice';
import {
  navigateToActivity,
  navigateToFirstActivity,
  navigateToLastActivity,
  navigateToNextActivity,
  navigateToPrevActivity,
} from '../../store/features/groups/actions/deck';
import { selectCurrentActivityTree } from '../../store/features/groups/selectors/deck';
import { selectPageContent } from '../../store/features/page/slice';
import FeedbackRenderer from './components/FeedbackRenderer';
import HistoryNavigation from './components/HistoryNavigation';

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

  const showDisabled = isLoading;
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

  const lastCheckTimestamp = useSelector(selectLastCheckTriggered);
  const lastCheckResults = useSelector(selectLastCheckResults);

  const [isLoading, setIsLoading] = useState(false);
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

  useEffect(() => {
    if (!lastCheckResults || !lastCheckResults.length) {
      return;
    }
    // when this changes, notify check has completed

    const isCorrect = lastCheckResults.every((r) => r.params.correct);

    // depending on combineFeedback value is whether we should address more than one event
    const combineFeedback = !!currentActivity.custom.combineFeedback;

    let eventsToProcess = [lastCheckResults[0]];
    if (combineFeedback) {
      eventsToProcess = lastCheckResults;
    }

    const actionsByType: any = {
      feedback: [],
      mutateState: [],
      navigation: [],
    };

    eventsToProcess.forEach((evt) => {
      const { actions } = evt.params;
      actions.forEach((action: any) => {
        actionsByType[action.type].push(action);
      });
    });

    const hasFeedback = actionsByType.feedback.length > 0;
    const hasNavigation = actionsByType.navigation.length > 0;

    if (actionsByType.mutateState.length) {
      const mutationsModified = actionsByType.mutateState.map((op: any) => {
        const ownerActivity = currentActivityTree?.find(
          (activity) => !!activity.content.partsLayout.find((p: any) => p.id === op.params.target),
        );
        const ownerId = ownerActivity
          ? `${ownerActivity}|${op.params.target}`
          : `${currentActivityId}|${op.params.target}`;

        const globalOp: ApplyStateOperation = {
          target: ownerId,
          operator: op.params.operator,
          value: op.params.value,
        };
        return globalOp;
      });

      console.log('FOOT MUTATION!', { mutationsModified });

      bulkApplyState(mutationsModified, defaultGlobalEnv);

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
    if (hasFeedback) {
      dispatch(
        setCurrentFeedbacks({
          feedbacks: actionsByType.feedback.map((fAction: any) => fAction.params.feedback),
        }),
      );
      dispatch(setIsGoodFeedback({ isGood: isCorrect }));
      // need to queue up the feedback display prior to nav
      if (isCorrect && hasNavigation) {
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
  }, [lastCheckResults]);

  const checkHandler = () => {
    setIsLoading(true);
    if (displayFeedback) setDisplayFeedback(false);

    // if (isGoodFeedback && canProceed) {
    if (isGoodFeedback) {
      dispatch(
        nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
      );
      dispatch(setIsGoodFeedback({ isGood: false }));
      dispatch(setNextActivityId({ nextActivityId: '' }));
    } else if (
      (!isLegacyTheme || !currentActivity?.custom?.showCheckBtn) &&
      !isGoodFeedback &&
      currentFeedbacks?.length > 0 &&
      displayFeedbackIcon
    ) {
      if (currentPage.custom?.advancedAuthoring && !currentPage.custom?.allownavigation) {
        dispatch(triggerCheck({ activityId: currentActivity.id }));
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
      //** DT - there are cases when wrong trap state gets trigger but user is still allowed to jump to another ensemble */
      //** if we don't do this then, every time Next button will trigger a check events instead of navigating user to respective ensemble */
      dispatch(
        nextActivityId === 'next' ? navigateToNextActivity() : navigateToActivity(nextActivityId),
      );
      dispatch(setNextActivityId({ nextActivityId: '' }));
    } else {
      dispatch(triggerCheck({ activityId: currentActivityId }));
    }
  };

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

  /*   useEffect(() => {
    const checkRequestInitiated = (data) => {
      setIsLoading(true);
    };
    const listener = (arg) => {
      checkRequestInitiated(arg.data);
    };
    componentEventService.on('checkRequestStart', listener);
    return () => {
      componentEventService.off('checkRequestStart', listener);
    };
  }, []);

  useEffect(() => {
    const checkRequestCompleted = (data) => {
      setIsLoading(false);
    };
    const listener = (arg) => {
      checkRequestCompleted(arg.data);
    };
    componentEventService.on('checkRequestCompleted', listener);
    return () => {
      componentEventService.off('checkRequestCompleted', listener);
    };
  }, []); */

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
        isLoading={isLoading}
        text={nextButtonText}
        handler={checkHandler}
        isGoodFeedbackPresent={isGoodFeedback}
        currentFeedbacksCount={currentFeedbacks.length}
        isFeedbackIconDisplayed={displayFeedbackIcon}
        showCheckBtn={currentActivity?.custom?.showCheckBtn}
      />
      <div className="feedbackContainer rowRestriction" style={{ top: 525 }}>
        <div className="bottomContainer fixed">
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
            <div className="content">
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
