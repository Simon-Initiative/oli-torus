import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { check } from '../../../../../../adaptivity/rules-engine';
import { navigateToNextActivity } from '../../groups/actions/deck';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import { selectPreviewMode } from '../../page/slice';
import { AdaptivitySlice, setLastCheckResults, setLastCheckTriggered } from '../slice';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string }, { dispatch, getState }) => {
    const rootState = getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);

    const currentActivityTree = selectCurrentActivityTree(rootState);
    if (!currentActivityTree || !currentActivityTree.length) {
      throw new Error('No Activity Tree, something very wrong!');
    }
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];

    // reset timeStartQuestion (per attempt timer, maybe should wait til resolved)
    // increase attempt number

    await dispatch(setLastCheckTriggered({ timestamp: Date.now() }));

    const stateSnapshot = {};

    let checkResult;
    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
      const currentRules = JSON.parse(JSON.stringify(currentActivity?.authoring?.rules || []));
      checkResult = await check(stateSnapshot, currentRules);
      console.log('CHECK RESULT', { currentActivity, currentRules, checkResult });
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

    // need to store check results so that if there are multiple things
    // like feedback *then* navigation

    /* await dispatch(navigateToNextActivity()); */
  },
);
