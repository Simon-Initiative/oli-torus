import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { PartResponse } from 'components/activities/types';
import { evalActivityAttempt, writePageAttemptState } from 'data/persistence/state/intrinsic';
import { check, CheckResult } from '../../../../../../adaptivity/rules-engine';
import {
  applyState,
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
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
import { AdaptivitySlice, setLastCheckResults, setLastCheckTriggered } from '../slice';

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
        if (isSessionVariable || isVarVariable) {
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
      console.log('trigger check last min extrinsic state', {
        sectionSlug,
        resourceAttemptGuid,
        extrnisicState,
      });
      await writePageAttemptState(sectionSlug, resourceAttemptGuid, extrnisicState);
    }

    let checkResult;
    let isCorrect = false;
    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
      const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
      // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
      const customRules = options.customRules || [];
      const rulesToCheck = customRules.length > 0 ? customRules : currentRules;

      /* console.log('PRE CHECK RESULT', { currentActivity, currentRules, localizedSnapshot }); */
      const check_call_result = (await check(localizedSnapshot, rulesToCheck)) as CheckResult;
      checkResult = check_call_result.results;
      isCorrect = check_call_result.correct;
      /* console.log('CHECK RESULT', {
        currentActivity,
        currentRules,
        checkResult,
        localizedSnapshot,
      }); */
    } else {
      /* console.log('CHECKING', {
        sectionSlug,
        currentActivityTreeAttempts,
        currentAttempt,
        currentActivityTree,
      }); */

      if (!currentActivityAttemptGuid) {
        console.error('not current attempt, cannot eval', { currentActivityTreeAttempts });
        return;
      }

      // BS: not sure why the current attempt responses are not up to date currently,
      // for now just merge the tree state into the current attempt
      // the LAYER is always up to date, but the current attempt is not for some reason
      // this only occurs with layers, more investigation needed

      // we have to send all the current activity attempt state to the server
      // because the server doesn't know the current sequence id and will strip out
      // all sequence ids from the path for these only
      const partResponses: PartResponse[] =
        currentAttempt?.parts.map(({ partId, attemptGuid, response }) => {
          // doing in reverse so that the layer's choice is the last one
          const combinedResponse = currentActivityTreeAttempts
            .reverse()
            .reduce((collect: any, attempt: any) => {
              const part = attempt.parts.find((p: any) => p.partId === partId);
              if (part) {
                if (part.response) {
                  // should update from snapshot now in case its newer??
                  collect = { ...collect, ...part.response };
                }
              }
              return collect;
            }, {});
          const finalResponse = Object.keys(combinedResponse).length > 0 ? combinedResponse : null;
          return { attemptGuid, response: { input: finalResponse } };
        }) || [];

      /* console.log('PART RESPONSES', { partResponses, allResponseState }); */

      const evalResult = await evalActivityAttempt(
        sectionSlug,
        currentActivityAttemptGuid,
        partResponses,
      );
      /* console.log('EVAL RESULT', { evalResult }); */
      checkResult = (evalResult.result as any).actions;
      isCorrect = checkResult.every((action: any) => action.params.correct);
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

    // scoring is based on properties of the activity
    if (!currentActivity.content.custom.trapStateScoreScheme) {
      // the trap states are not in charge of the score, so use attempts & max
      const maxScore = currentActivity.content.custom.maxScore || 0;
      const maxAttempt = currentActivity.content.custom.maxAttempt || 0;
      const negativeScoreAllowed = currentActivity.content.custom.negativeScoreAllowed || false;
      if (maxAttempt > 0) {
        const scorePerAttempt = maxScore / maxAttempt;
        const numberOfAttempts = attempt.attemptNumber;
        let score = maxScore - scorePerAttempt * (numberOfAttempts - 1);
        if (!negativeScoreAllowed) {
          score = Math.max(0, score);
        }

        /* console.log('SCORING: ', {
          score,
          numberOfAttempts,
          scorePerAttempt,
          maxScore,
          maxAttempt,
          currentActivity,
          attempt,
        }); */
        // only apply this to the scripting env since it should be calculated for real on the server
        applyState(
          { target: 'session.currentQuestionScore', operator: '=', value: score },
          defaultGlobalEnv,
        );
      }
    }

    await dispatch(
      setLastCheckResults({ timestamp: currentTriggerStamp, results: checkResult, attempt }),
    );
  },
);
