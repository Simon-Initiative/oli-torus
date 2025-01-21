import { EntityId, createAsyncThunk } from '@reduxjs/toolkit';
import { PartResponse } from 'components/activities/types';
import {
  checkIfFirstEventHasNavigation,
  processResults,
} from 'apps/delivery/layouts/deck/DeckLayoutFooter';
import { DeliveryRootState } from 'apps/delivery/store/rootReducer';
import { evalActivityAttempt, writePageAttemptState } from 'data/persistence/state/intrinsic';
import { clone } from 'utils/common';
import { CheckResult, ScoringContext, check } from '../../../../../../adaptivity/rules-engine';
import {
  ApplyStateOperation,
  applyState,
  bulkApplyState,
  defaultGlobalEnv,
  getEnvState,
  getLocalizedStateSnapshot,
  getValue,
} from '../../../../../../adaptivity/scripting';
import { createActivityAttempt } from '../../attempt/actions/createActivityAttempt';
import {
  selectAll as selectAllAttempts,
  selectExtrinsicState,
  updateExtrinsicState,
  upsertActivityAttemptState,
} from '../../attempt/slice';
import { findNextSequenceId } from '../../groups/actions/deck';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
} from '../../groups/selectors/deck';
import { selectPreviewMode, selectResourceAttemptGuid, selectSectionSlug } from '../../page/slice';
import AdaptivitySlice from '../name';
import { setLastCheckResults, setLastCheckTriggered } from '../slice';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string; customRules?: any[] }, { dispatch, getState }) => {
    const rootState = getState() as DeliveryRootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);

    const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
    const currentAttempt = currentActivityTreeAttempts[currentActivityTreeAttempts?.length - 1];
    const currentActivityAttemptGuid = currentAttempt?.attemptGuid || '';

    const currentActivityTree = selectCurrentActivityTree(rootState);
    if (!currentActivityTree || !currentActivityTree.length) {
      throw new Error('No Activity Tree, something very wrong!');
    }
    const [currentActivity] = currentActivityTree.slice(-1);

    // update time on question
    applyState(
      {
        target: 'session.timeOnQuestion',
        operator: '=',
        value: `${Date.now()} - {session.timeStartQuestion}`,
      },
      defaultGlobalEnv,
    );

    // for history tracking
    const trackingStampKey = `session.visitTimestamps.${currentActivity.id}`;
    const isActivityAlreadyVisited = !!getValue(trackingStampKey, defaultGlobalEnv);
    // don't update the time if student is revisiting that page
    if (!isActivityAlreadyVisited) {
      // looks like SS captures the date when we leave the page so we will capture the time here for tracking history
      // update the scripting
      const targetVisitTimeStampOp: ApplyStateOperation = {
        target: trackingStampKey,
        operator: '=',
        value: Date.now(),
      };
      applyState(targetVisitTimeStampOp, defaultGlobalEnv);
    }

    //update the store with the latest changes
    const currentTriggerStamp = Date.now();
    await dispatch(setLastCheckTriggered({ timestamp: currentTriggerStamp }));

    const treeActivityIds = currentActivityTree.map((a) => a.id);
    const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);
    const extrinsicSnapshot = Object.keys(localizedSnapshot).reduce(
      (acc: Record<string, any>, key) => {
        const isSessionVariable = key.startsWith('session.');
        const isVarVariable = key.startsWith('variables.');
        const isEverAppVariable = key.startsWith('app.');
        if (isSessionVariable || isVarVariable || isEverAppVariable) {
          acc[key] = localizedSnapshot[key];
        }
        return acc;
      },
      {},
    );
    // update redux first because we need to get the latest full extrnisic state to write to the server
    await dispatch(updateExtrinsicState({ state: extrinsicSnapshot }));

    const extrnisicState = selectExtrinsicState(getState() as DeliveryRootState);
    if (!isPreviewMode) {
      // update the server with the latest changes to extrinsic state

      /* console.log('trigger check last min extrinsic state', {
        sectionSlug,
        resourceAttemptGuid,
        extrnisicState,
      }); */
      await writePageAttemptState(sectionSlug, resourceAttemptGuid, extrnisicState);
    }

    let checkResult;
    let isCorrect = false;
    let score = 0;
    let outOf = 0;

    // prepare state to send to the rules engine
    {
      // these were previously declared, but after above async calls they might have been updated, lets get them again
      const rootState = getState() as DeliveryRootState;
      const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
      const [currentAttempt] = currentActivityTreeAttempts.slice(-1);

      const treeActivityIds = currentActivityTree.map((a) => a.id).reverse();
      const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);

      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      const partResponses: PartResponse[] = currentAttempt!.parts.map(
        ({ partId, attemptGuid, response }) => {
          // snapshot is more up to date
          // TODO: resolve syncing issue, this is a workaround
          let finalResponse = response;
          if (!finalResponse) {
            // if a null response, it actually might live on a parent attempt
            // walk backwards to find the parent
            finalResponse = currentActivityTreeAttempts.reduce((acc, attempt) => {
              const part = attempt?.parts.find((p) => p.partId === partId);
              return part?.response || acc;
            }, null);
          }
          if (finalResponse) {
            finalResponse = Object.keys(finalResponse).reduce((acc: any, key) => {
              acc[key] = { ...finalResponse[key] };
              const item = acc[key];
              if (item.path) {
                const snapshotValue = localizedSnapshot[item.path];
                if (snapshotValue !== undefined) {
                  item.value = snapshotValue;
                }
              }
              return acc;
            }, {});
          }
          return {
            attemptGuid,
            response: { input: finalResponse },
          };
        },
      );

      if (isPreviewMode) {
        // in preview mode we need to do the same logic that we do on the server (evaluate.ex)
        const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
        // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
        const customRules = options.customRules || [];
        const rulesToCheck = customRules.length > 0 ? customRules : currentRules;

        let requiredVariables = currentActivity?.authoring?.variablesRequiredForEvaluation;
        if (!requiredVariables) {
          // assume they are all required since authoring hasn't specified
          console.warn('No variables required for evaluation, assuming all are required');
          requiredVariables = Object.keys(localizedSnapshot);
        }

        const requiredActivities =
          currentActivity?.authoring?.activitiesRequiredForEvaluation || [];

        const allAttempts = selectAllAttempts(rootState);

        // the server doesn't get the snapshot, instead it gets the part responses for the current submission
        // and then can access any previous attempt information necessary to evaluate the rules

        // checkSnapshot is: extrinsicState + other activity state + part responses
        const otherActivityState = requiredActivities.reduce((acc: any, activityId: any) => {
          // on the server, this must be found in the attempt state db
          const activityAttempt = allAttempts.find((a) => a.activityId === activityId);
          if (!activityAttempt) {
            console.warn(
              `Activity Attempt ${activityId} not found (building required activity state)`,
            );
            return acc;
          }

          activityAttempt.parts.forEach((part) => {
            if (part.response) {
              Object.keys(part.response).forEach((key) => {
                const resItem = part.response[key];
                // these are NOT expected to be "local" since they are coming from "other" activities
                acc[resItem.path] = resItem.value;
              });
            }
          });

          return acc;
        }, {});

        const partResponseState = partResponses.reduce((acc: any, pr) => {
          const input = pr.response?.input || {};
          Object.keys(input).forEach((key) => {
            const inputItem = input[key];
            if (inputItem.path) {
              const snapshotValue = localizedSnapshot[inputItem.path];
              // the server will only have the path, doesn't know the current sequence id
              // all inputs are considered "local" to the current attempt, so strip off any sequenceId from the path
              let itemId = inputItem.path.split('|stage').slice(-1)[0];
              if (itemId.startsWith('.')) {
                itemId = `stage${itemId}`;
              }
              acc[itemId] = snapshotValue;
            }
          });
          return acc;
        }, {});

        let checkSnapshot = { ...extrnisicState, ...otherActivityState, ...partResponseState };

        // filter the keys of the snapshot to only include the ones that are required
        checkSnapshot = Object.keys(checkSnapshot).reduce((acc: any, key) => {
          if (requiredVariables.includes(key)) {
            acc[key] = checkSnapshot[key];
          }
          return acc;
        }, {});

        const scoringContext: ScoringContext = {
          currentAttemptNumber: currentAttempt?.attemptNumber || 1,
          maxAttempt: currentActivity.content?.custom.maxAttempt || 0,
          maxScore: currentActivity.content?.custom.maxScore || 0,
          trapStateScoreScheme: currentActivity.content?.custom.trapStateScoreScheme || false,
          negativeScoreAllowed: currentActivity.content?.custom.negativeScoreAllowed || false,
          isManuallyGraded: !!currentActivity.authoring?.parts?.some(
            (p: any) => p.gradingApproach === 'manual',
          ),
        };

        console.log('PRE CHECK RESULT (PREVIEW)', {
          sectionSlug,
          extrnisicState,
          partResponses,
          partResponseState,
          otherActivityState,
          allAttempts,
          currentActivityTreeAttempts,
          currentAttempt,
          currentActivity,
          currentRules,
          localizedSnapshot,
          checkSnapshot,
          requiredActivities,
          requiredVariables,
        });

        const check_call_result = (await check(
          checkSnapshot,
          rulesToCheck,
          scoringContext,
        )) as CheckResult;
        checkResult = check_call_result.results;
        isCorrect = check_call_result.correct;
        score = check_call_result.score;
        outOf = check_call_result.out_of;

        console.log('POST CHECK RESULT (PREVIEW)', {
          check_call_result,
          currentActivity,
          currentRules,
          checkResult,
          localizedSnapshot,
          checkSnapshot,
          currentActivityTreeAttempts,
          currentAttempt,
          currentActivityTree,
        });
      } else {
        console.log('PRE CHECK RESULT (DD)', {
          sectionSlug,
          currentActivityTreeAttempts,
          currentAttempt,
          currentActivityTree,
          localizedSnapshot,
          partResponses,
        });

        const evalResult = await evalActivityAttempt(
          sectionSlug,
          currentActivityAttemptGuid,
          partResponses,
        );

        const resultData: CheckResult = (evalResult as any).result.actions;
        checkResult = resultData.results;
        isCorrect = resultData.correct;
        score = resultData.score;
        outOf = resultData.out_of;

        console.log('POST CHECK RESULT (DD)', {
          currentActivity,
          checkResult,
          localizedSnapshot,
          currentActivityTreeAttempts,
          currentAttempt,
          currentActivityTree,
        });
      }
    }

    // after the check is done, we need to update the activity attempt (in memory, on server it is already updated)

    let attempt: any = clone(currentAttempt);

    attempt.score = score;
    attempt.outOf = outOf;
    attempt.dateSubmitted = Date.now();
    attempt.dateEvaluated = Date.now();

    await dispatch(upsertActivityAttemptState({ attempt }));
    let doesCheckResultContainsNavigationToDifferentScreen = false;
    const actionsByType = processResults(checkResult);
    const hasFeedback = actionsByType.feedback.length > 0;
    const hasNavigation = actionsByType.navigation.length > 0;
    let expectedResumeActivityId: EntityId = currentActivity.id;
    //check if the check result have any navigation else don't do anything
    if (checkResult.length && hasNavigation) {
      const doesFirstEventHasNavigation = checkIfFirstEventHasNavigation(checkResult[0]);
      const [firstNavAction] = actionsByType.navigation;
      const navTarget = firstNavAction.params.target;
      if (
        hasFeedback &&
        hasNavigation &&
        navTarget !== expectedResumeActivityId &&
        doesFirstEventHasNavigation
      ) {
        doesCheckResultContainsNavigationToDifferentScreen = true;
      }
      // if the check result contains a 'correct' trap state and user will be redirected to another screen, we need
      //to reset the session.attemptNumber to 1. We already reset the session.attemptNumber when we initialize the activity
      // but we reset it after each part calls 'onOnit'. So, during savePart, previous screen attempt number
      //was getting saved in currentAttempt.attemptNumber which was incorrect.
      if (
        isCorrect &&
        hasNavigation &&
        navTarget !== expectedResumeActivityId &&
        doesFirstEventHasNavigation
      ) {
        const updateSessionAttempt: ApplyStateOperation[] = [
          {
            target: 'session.attemptNumber',
            operator: '=',
            value: 1,
          },
        ];
        bulkApplyState(updateSessionAttempt, defaultGlobalEnv);
      }
    }
    //Even If the check result contains a wrong trap state and has a navigation to different screen, we should not create a new attempt for that screen because
    // the student will be navigated to different screen so it does not make sense to create a new attempt for the current screen
    if (
      !isCorrect &&
      !doesCheckResultContainsNavigationToDifferentScreen &&
      attempt?.hasMoreAttempts
    ) {
      /* console.log('Incorrect, time for new attempt'); */
      const { payload: newAttempt } = await dispatch(
        createActivityAttempt({ sectionSlug, attemptGuid: currentActivityAttemptGuid }),
      );
      if (attempt) attempt = newAttempt;
      const updateSessionAttempt: ApplyStateOperation[] = [
        {
          target: 'session.attemptNumber',
          operator: '=',
          value: attempt.attemptNumber,
        },
        {
          target: `${currentActivity.id}|session.attemptNumber`,
          operator: '=',
          value: attempt.attemptNumber,
        },
      ];
      bulkApplyState(updateSessionAttempt, defaultGlobalEnv);
      // need to write attempt number to extrinsic state?
      // TODO: also get attemptNumber alwasy from the attempt and update scripting instead
    }

    const updateScoreAndVisit: ApplyStateOperation[] = [
      { target: 'session.currentQuestionScore', operator: '=', value: score },
    ];
    /* console.log('VISITS', { visit: attempt.attemptNumber <= 2 }); */
    // because visit count doesn't increase until AFTER checking is done, it could be 1 or 2 depending
    // on whether or not it was correct
    if (attempt.attemptNumber <= 2) {
      updateScoreAndVisit.push({
        target: `session.visits.${currentActivity.id}`,
        operator: '+',
        value: 1,
      });
    }
    bulkApplyState(updateScoreAndVisit, defaultGlobalEnv);

    // after these final extrinsic state updates, we need to write it again
    // update redux first because we need to get the latest full extrnisic state to write to the server
    const latestSnapshot = getEnvState(defaultGlobalEnv);
    const latestExtrinsic = Object.keys(latestSnapshot).reduce((acc: Record<string, any>, key) => {
      const isSessionVariable = key.startsWith('session.');
      const isVarVariable = key.startsWith('variables.');
      const isEverAppVariable = key.startsWith('app.');
      if (isSessionVariable || isVarVariable || isEverAppVariable) {
        acc[key] = latestSnapshot[key];
      }
      return acc;
    }, {});
    await dispatch(updateExtrinsicState({ state: latestExtrinsic }));

    if (!isPreviewMode) {
      if (doesCheckResultContainsNavigationToDifferentScreen) {
        const [firstNavAction] = actionsByType.navigation;
        const navTarget = firstNavAction.params.target;
        switch (navTarget) {
          case 'next':
            const { payload: nextActivityId } = await dispatch(findNextSequenceId('next'));
            expectedResumeActivityId = nextActivityId as EntityId;
            break;
          default:
            const { payload: expectedNextActivityId } = await dispatch(
              findNextSequenceId(navTarget),
            );
            expectedResumeActivityId = expectedNextActivityId as EntityId;
        }
        if (expectedResumeActivityId) {
          const resumeTarget: ApplyStateOperation = {
            target: `session.resume`,
            operator: '=',
            value: expectedResumeActivityId,
          };
          await applyState(resumeTarget, defaultGlobalEnv);
          const latestSnapshot = getEnvState(defaultGlobalEnv);

          const latestExtrinsic = Object.keys(latestSnapshot).reduce(
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
          await dispatch(updateExtrinsicState({ state: latestExtrinsic }));
        }
      }
      // update the server with the latest changes
      const extrnisicState = selectExtrinsicState(getState() as DeliveryRootState);
      /* console.log('trigger check last min extrinsic state', {
        sectionSlug,
        resourceAttemptGuid,
        extrnisicState,
      }); */
      await writePageAttemptState(sectionSlug, resourceAttemptGuid, extrnisicState);
    }
    await dispatch(
      setLastCheckResults({
        timestamp: currentTriggerStamp,
        results: checkResult,
        attempt,
        correct: isCorrect,
        score,
        outOf,
      }),
    );
  },
);
