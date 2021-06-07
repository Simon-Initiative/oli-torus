import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { check } from '../../../../../../adaptivity/rules-engine';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
} from '../../../../../../adaptivity/scripting';
import { selectAll, selectExtrinsicState, setExtrinsicState } from '../../attempt/slice';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import { selectPreviewMode } from '../../page/slice';
import { AdaptivitySlice, setLastCheckResults, setLastCheckTriggered } from '../slice';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string; customRules?: any[] }, { dispatch, getState }) => {
    const rootState = getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);

    const currentActivityTree = selectCurrentActivityTree(rootState);
    if (!currentActivityTree || !currentActivityTree.length) {
      throw new Error('No Activity Tree, something very wrong!');
    }
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];

    // reset timeStartQuestion (per attempt timer, maybe should wait til resolved)
    // increase attempt number
    const extrinsicState = selectExtrinsicState(rootState);
    const modifiedExtrinsicState = [extrinsicState]?.reduce((collect: any, entry: any) => {
      Object.keys(entry).forEach((key) => {
        collect[key] = extrinsicState[key];
      });
      return collect;
    }, {});
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

    bulkApplyState(updateScripting, defaultGlobalEnv);

    await dispatch(setExtrinsicState({ state: modifiedExtrinsicState }));

    //update the store with the latest changes
    await dispatch(setLastCheckTriggered({ timestamp: Date.now() }));

    // this needs to be the attempt state
    // at the very least needs the "local" version `stage.foo.whatevr` vs `q:1234|stage.foo.whatever`
    // server side we aren't going to have the scripting engine until just in time (for condition eval)
    // so the logic here should mimic server and pull only attempt state
    const allActivityAttempts = selectAll(rootState);
    const allResponseState = allActivityAttempts.reduce((collect: any, attempt: any) => {
      attempt.parts.forEach((part: any) => {
        if (part.response) {
          Object.keys(part.response).forEach((key) => {
            collect[part.response[key].path] = part.response[key].value;
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
    const stateSnapshot = { ...allResponseState, ...modifiedExtrinsicState };

    let checkResult;
    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
      const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
      // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
      const customRules = options.customRules || [];
      const rulesToCheck = customRules.length > 0 ? customRules : currentRules;

      /* console.log('PRE CHECK RESULT', { currentActivity, currentRules, stateSnapshot }); */
      checkResult = await check(stateSnapshot, rulesToCheck);
      console.log('CHECK RESULT', {
        currentActivity,
        currentRules,
        checkResult,
        stateSnapshot,
      });
    } else {
      // server mode (delivery) TODO
      checkResult = [
        {
          type: 'correct',
          params: {
            actions: [{ params: { target: 'next' }, type: 'navigation' }],
            order: 1,
            correct: true,
          },
        },
      ];
    }

    await dispatch(setLastCheckResults({ results: checkResult }));
  },
);
