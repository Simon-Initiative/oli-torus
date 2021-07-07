import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { PartResponse } from 'components/activities/types';
import { evalActivityAttempt, writePageAttemptState } from 'data/persistence/state/intrinsic';
import { check } from '../../../../../../adaptivity/rules-engine';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getEnvState,
} from '../../../../../../adaptivity/scripting';
import { createActivityAttempt } from '../../attempt/actions/createActivityAttempt';
import { selectAll, selectExtrinsicState, setExtrinsicState } from '../../attempt/slice';
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

    /* console.log('TRIGGER CHECK', {currentAttempt}); */

    const currentActivityTree = selectCurrentActivityTree(rootState);
    if (!currentActivityTree || !currentActivityTree.length) {
      throw new Error('No Activity Tree, something very wrong!');
    }
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];

    // reset timeStartQuestion (per attempt timer, maybe should wait til resolved)
    // increase attempt number
    const extrinsicState = selectExtrinsicState(rootState);
    const modifiedExtrinsicState = Object.keys(extrinsicState).reduce(
      (collect: any, key: string) => {
        collect[key] = extrinsicState[key];
        return collect;
      },
      {},
    );
    const timeStartQuestion = modifiedExtrinsicState['session.timeStartQuestion'];
    const timeOnQuestion = Date.now() - timeStartQuestion;
    modifiedExtrinsicState['session.timeOnQuestion'] = timeOnQuestion;

    const currentAttemptNumber = modifiedExtrinsicState['session.attemptNumber'];
    modifiedExtrinsicState['session.attemptNumber'] = currentAttemptNumber + 1;
    modifiedExtrinsicState[`${currentActivity.id}|session.attemptNumber`] =
      currentAttemptNumber + 1;

    const updateScripting: ApplyStateOperation[] = [
      {
        target: 'session.timeOnQuestion',
        operator: '=',
        value: timeOnQuestion,
      },
      {
        target: 'session.attemptNumber',
        operator: '=',
        value: currentAttemptNumber + 1,
      },
      {
        target: `${currentActivity.id}|session.attemptNumber`,
        operator: '=',
        value: currentAttemptNumber + 1,
      },
    ];
    let globalSnapshot = getEnvState(defaultGlobalEnv);
    const isActivityAlreadyVisited = globalSnapshot[`${currentActivity.id}|visitTimestamp`];
    // don't update the time if student is revisiting that page
    if (!isActivityAlreadyVisited) {
      //looks like SS captures the date when we leave the page so we will capture the time here for tracking history
      // update the scripting
      const targetVisitTimeStampOp: ApplyStateOperation = {
        target: `${currentActivity.id}|visitTimestamp`,
        operator: '=',
        value: Date.now(),
      };
      updateScripting.push(targetVisitTimeStampOp);
      // update the store
      modifiedExtrinsicState[`${currentActivity.id}|visitTimestamp`] = Date.now();
    }
    bulkApplyState(updateScripting, defaultGlobalEnv);

    //update the store with the latest changes
    const currentTriggerStamp = Date.now();
    await dispatch(setLastCheckTriggered({ timestamp: currentTriggerStamp }));

    // this needs to be the attempt state
    // at the very least needs the "local" version `stage.foo.whatevr` vs `q:1234|stage.foo.whatever`
    // server side we aren't going to have the scripting engine until just in time (for condition eval)
    // so the logic here should mimic server and pull only attempt state
    const allActivityAttempts = selectAll(rootState);
    const allResponseState = allActivityAttempts.reduce((collect: any, attempt: any) => {
      attempt.parts.forEach((part: any) => {
        if (part.response) {
          Object.keys(part.response).forEach((key) => {
            const input_response = part.response[key];
            if (!input_response) {
              return;
            }
            const { path, value } = input_response;
            if (!path) {
              return;
            }
            collect[path] = value;
          });
        }
      });
      return collect;
    }, {});
    // need to duplicate "local" state based on current sequenceId
    Object.keys(allResponseState).forEach((key) => {
      // need to localize for all layers
      currentActivityTree.forEach((activity) => {
        if (key.indexOf(`${activity.id}|`) === 0) {
          const localKey = key.replace(`${activity.id}|`, '');
          allResponseState[localKey] = allResponseState[key];
        }
      });
    });

    const snapshot = getEnvState(defaultGlobalEnv);
    globalSnapshot = Object.keys(snapshot).reduce((collect: any, key: string) => {
      if (key.indexOf('app.') === 0 || key.indexOf('variables.') === 0) {
        collect[key] = snapshot[key];
      }
      return collect;
    }, {});

    if (!isPreviewMode) {
      // update the server with the latest changes
      /* console.log('trigger check last min extrinsic state', {
        sectionSlug,
        resourceAttemptGuid,
        modifiedExtrinsicState,
      }); */
      await writePageAttemptState(sectionSlug, resourceAttemptGuid, modifiedExtrinsicState);
    }
    await dispatch(setExtrinsicState({ state: modifiedExtrinsicState }));
    const stateSnapshot = {
      ...allResponseState,
      ...modifiedExtrinsicState,
      ...globalSnapshot,
    };

    let checkResult;
    let isCorrect = false;
    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
      const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
      // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
      const customRules = options.customRules || [];
      const rulesToCheck = customRules.length > 0 ? customRules : currentRules;

      /* console.log('PRE CHECK RESULT', { currentActivity, currentRules, stateSnapshot }); */
      const check_call_result = await check(stateSnapshot, rulesToCheck);
      checkResult = check_call_result.results;
      isCorrect = check_call_result.correct;
      /* console.log('CHECK RESULT', {
        currentActivity,
        currentRules,
        checkResult,
        stateSnapshot,
      }); */
    } else {
      const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
      const currentAttempt = currentActivityTreeAttempts[currentActivityTreeAttempts?.length - 1];
      const currentActivityAttemptGuid = currentAttempt?.attemptGuid || '';
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
          const combinedResponse = currentActivityTreeAttempts.reverse().reduce(
            (collect: any, attempt: any) => {
              const part = attempt.parts.find((p: any) => p.partId === partId);
              if (part) {
                /* if (partId === 'orrery') {
                  console.log('collecting parts:', { part, attempt, response, pr: part.response });
                } */
                if (part.response) {
                  collect = {...collect, ...part.response};
                }
              }
              return collect;
            },
            {},
          );
          const finalResponse = Object.keys(combinedResponse).length > 0 ? combinedResponse : null;
          // response should be wrapped in input, but only once
          /* const input_response = response?.input ? response : { input: response }; */
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

    const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
    const currentAttempt = currentActivityTreeAttempts[currentActivityTreeAttempts?.length - 1];
    const currentActivityAttemptGuid = currentAttempt?.attemptGuid || '';
    let attempt: any = currentAttempt;
    if (!isCorrect) {
      /* console.log('Incorrect, time for new attempt'); */
      const { payload: newAttempt } = await dispatch(
        createActivityAttempt({ sectionSlug, attemptGuid: currentActivityAttemptGuid }),
      );
      attempt = newAttempt;
    }

    await dispatch(
      setLastCheckResults({ timestamp: currentTriggerStamp, results: checkResult, attempt }),
    );
  },
);
