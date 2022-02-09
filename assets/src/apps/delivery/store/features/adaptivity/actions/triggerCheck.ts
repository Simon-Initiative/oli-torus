import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { PartResponse } from 'components/activities/types';
import { evalActivityAttempt, writePageAttemptState } from 'data/persistence/state/intrinsic';
import { check, CheckResult, ScoringContext } from '../../../../../../adaptivity/rules-engine';
import {
  applyState,
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getEnvState,
  getLocalizedStateSnapshot,
  getValue,
} from '../../../../../../adaptivity/scripting';
import { createActivityAttempt } from '../../attempt/actions/createActivityAttempt';
import { selectExtrinsicState, updateExtrinsicState } from '../../attempt/slice';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
} from '../../groups/selectors/deck';
import { selectPreviewMode, selectResourceAttemptGuid, selectSectionSlug } from '../../page/slice';
import { setLastCheckResults, setLastCheckTriggered } from '../slice';
import AdaptivitySlice from '../name';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string; customRules?: any[] }, { dispatch, getState }) => {
    const rootState = getState() as RootState;
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

    if (!isPreviewMode) {
      // update the server with the latest changes
      const extrnisicState = selectExtrinsicState(getState() as RootState);
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

    const scoringContext: ScoringContext = {
      currentAttemptNumber: currentAttempt?.attemptNumber || 1,
      maxAttempt: currentActivity.content.custom.maxAttempt || 0,
      maxScore: currentActivity.content.custom.maxScore || 0,
      trapStateScoreScheme: currentActivity.content.custom.trapStateScoreScheme || false,
      negativeScoreAllowed: currentActivity.content.custom.negativeScoreAllowed || false,
    };

    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
      // need to get this fresh right now so it is the latest
      const rootState = getState() as RootState;
      const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
      const [currentAttempt] = currentActivityTreeAttempts.slice(-1);

      const treeActivityIds = currentActivityTree.map((a) => a.id).reverse();
      const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);

      const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
      // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
      const customRules = options.customRules || [];
      const rulesToCheck = customRules.length > 0 ? customRules : currentRules;

      let requiredVariables = currentActivity?.authoring?.variablesRequiredForEvaluation;
      if (!requiredVariables) {
        // assume they are all required since authoring hasn't specified
        requiredVariables = Object.keys(localizedSnapshot);
      }
      const checkSnapshot = Object.keys(localizedSnapshot).reduce((acc: any, key) => {
        const isRequiredKey = requiredVariables.includes(key);
        if (isRequiredKey) {
          acc[key] = localizedSnapshot[key];
        }
        return acc;
      }, {});

      console.log('PRE CHECK RESULT', {
        currentActivity,
        currentRules,
        localizedSnapshot,
        requiredVariables,
        checkSnapshot,
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
      console.log('CHECK RESULT', {
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
      // need to get this fresh right now so it is the latest
      const rootState = getState() as RootState;
      const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
      const [currentAttempt] = currentActivityTreeAttempts.slice(-1);

      if (!currentActivityAttemptGuid) {
        console.error('not current attempt, cannot eval', { currentActivityAttemptGuid });
        return;
      }

      // we have to send all the current activity attempt state to the server
      // because the server doesn't know the current sequence id and will strip out
      // all sequence ids from the path for these only

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

      /* console.log('CHECKING', {
        sectionSlug,
        currentActivityTreeAttempts,
        currentAttempt,
        currentActivityTree,
        localizedSnapshot,
        partResponses,
      }); */

      const evalResult = await evalActivityAttempt(
        sectionSlug,
        currentActivityAttemptGuid,
        partResponses,
      );

      /* console.log('EVAL RESULT', { evalResult }); */
      const resultData: CheckResult = (evalResult as any).result.actions;
      checkResult = resultData.results;
      isCorrect = resultData.correct;
      score = resultData.score;
      outOf = resultData.out_of;
    }

    let attempt: any = currentAttempt;
    if (!isCorrect) {
      /* console.log('Incorrect, time for new attempt'); */
      const { payload: newAttempt } = await dispatch(
        createActivityAttempt({ sectionSlug, attemptGuid: currentActivityAttemptGuid }),
      );
      attempt = newAttempt;
      const updateAttempt: ApplyStateOperation[] = [
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
      bulkApplyState(updateAttempt, defaultGlobalEnv);
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
      // update the server with the latest changes
      const extrnisicState = selectExtrinsicState(getState() as RootState);
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
