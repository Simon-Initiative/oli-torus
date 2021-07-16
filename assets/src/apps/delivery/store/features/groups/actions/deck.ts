import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { getBulkActivitiesForAuthoring } from 'data/persistence/activity';
import {
  getBulkAttemptState,
  getPageAttemptState,
  writePageAttemptState,
} from 'data/persistence/state/intrinsic';
import { ResourceId } from 'data/types';
import guid from 'utils/guid';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  evalScript,
  getAssignScript,
  getEnvState,
  getLocalizedStateSnapshot,
  removeStateValues,
} from '../../../../../../adaptivity/scripting';
import { RootState } from '../../../rootReducer';
import {
  selectCurrentActivity,
  selectCurrentActivityId,
  setActivities,
  setCurrentActivityId,
} from '../../activities/slice';
import { setLessonEnd } from '../../adaptivity/slice';
import { loadActivityAttemptState, updateExtrinsicState } from '../../attempt/slice';
import {
  selectActivityTypes,
  selectEnableHistory,
  selectNavigationSequence,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectSectionSlug,
  setScore,
} from '../../page/slice';
import { selectCurrentActivityTree, selectSequence } from '../selectors/deck';
import { GroupsSlice } from '../slice';
import { getNextQBEntry, getParentBank } from './navUtils';
import { SequenceBank, SequenceEntry, SequenceEntryType } from './sequence';

export const initializeActivity = createAsyncThunk(
  `${GroupsSlice}/deck/initializeActivity`,
  async (activityId: ResourceId, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const isHistoryModeOn = selectEnableHistory(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentSequenceId = sequence.find((entry) => entry.activity_id === activityId)?.custom
      .sequenceId;
    if (!currentSequenceId) {
      throw new Error(`Activity ${activityId} not found in sequence!`);
    }
    const currentActivity = selectCurrentActivity(rootState);
    const currentActivityTree = selectCurrentActivityTree(rootState);

    const resumeTarget: ApplyStateOperation = {
      target: `session.resume`,
      operator: '=',
      value: currentSequenceId,
    };
    const visitOperation: ApplyStateOperation = {
      target: `session.visits.${currentSequenceId}`,
      operator: '+',
      value: 1,
    };
    const timeOnQuestion: ApplyStateOperation = {
      target: 'session.timeOnQuestion',
      operator: '=',
      value: 0,
    };
    const timeStartOp: ApplyStateOperation = {
      target: 'session.timeStartQuestion',
      operator: '=',
      value: Date.now(),
    };
    const timeExceededOp: ApplyStateOperation = {
      target: 'session.questionTimeExceeded',
      operator: '=',
      value: false,
    };
    const currentAttempNumber = 1;
    const attemptNumberOp: ApplyStateOperation = {
      target: 'session.attemptNumber',
      operator: '=',
      value: currentAttempNumber,
    };
    const targettedAttemptNumberOp: ApplyStateOperation = {
      target: `${currentSequenceId}|session.attemptNumber`,
      operator: '=',
      value: currentAttempNumber,
    };
    const tutorialScoreOp: ApplyStateOperation = {
      target: 'session.tutorialScore',
      operator: '+',
      value: '{session.currentQuestionScore}',
    };
    const currentScoreOp: ApplyStateOperation = {
      target: 'session.currentQuestionScore',
      operator: '=',
      value: 0,
    };

    const sessionOps = [
      resumeTarget,
      visitOperation,
      timeStartOp,
      timeOnQuestion,
      timeExceededOp,
      attemptNumberOp,
      targettedAttemptNumberOp,
      tutorialScoreOp,
      // must come *after* the tutorial score op
      currentScoreOp,
    ];

    const globalSnapshot = getEnvState(defaultGlobalEnv);
    const trackingStampKey = `session.visitTimestamps.${currentSequenceId}`;
    const isActivityAlreadyVisited = globalSnapshot[trackingStampKey];
    // don't update the time if student is revisiting that page
    if (!isActivityAlreadyVisited) {
      // looks like SS captures the date when we leave the page but it should
      // show in the history as soon as we visit but it does not show the timestamp
      // so we will capture the time on trigger check
      const targetVisitTimeStampOp: ApplyStateOperation = {
        target: trackingStampKey,
        operator: '=',
        value: 0,
      };
      sessionOps.push(targetVisitTimeStampOp);
    }

    //Need to clear out snapshot for the current activity before we send the init trap state.
    // this is needed for use cases where, when we re-visit an activity screen, it needs to restart fresh otherwise
    // some screens go in loop
    // Don't do anything id isHistoryModeOn is ON
    if (!isHistoryModeOn && currentActivityTree) {
      const currentActivityId = currentActivityTree[currentActivityTree.length - 1].id;

      const currentActivitySnapshot = getLocalizedStateSnapshot(
        [currentActivityId],
        defaultGlobalEnv,
      );

      const idsToBeRemoved: any[] = Object.keys(currentActivitySnapshot)
        .map((key: string) => {
          if (key.indexOf(currentActivityId) === 0 || key.indexOf('stage.') === 0) {
            return key;
          }
        })
        .filter((item) => item);
      if (idsToBeRemoved) {
        removeStateValues(defaultGlobalEnv, idsToBeRemoved);
      }
    }
    // init state is always "local" but the parts may come from parent layers
    // in that case they actually need to be written to the parent layer values
    const initState = currentActivity?.content?.custom?.facts || [];
    const globalizedInitState = initState.map((s: any) => {
      if (s.target.indexOf('stage.') !== 0) {
        return { ...s };
      }
      const [, targetPart] = s.target.split('.');
      const ownerActivity = currentActivityTree?.find(
        (activity) => !!activity.content.partsLayout.find((p: any) => p.id === targetPart),
      );
      if (!ownerActivity) {
        // shouldn't happen, but ignore I guess
        return { ...s };
      }
      return { ...s, target: `${ownerActivity.id}|${s.target}` };
    });

    const results = bulkApplyState([...sessionOps, ...globalizedInitState], defaultGlobalEnv);
    // now that the scripting env should be up to date, need to update attempt state in redux and server
    console.log('INIT STATE OPS', { results, ops: [...sessionOps, ...globalizedInitState] });
    const currentState = getEnvState(defaultGlobalEnv);
    const sessionState = Object.keys(currentState).reduce((collect: any, key) => {
      if (key.indexOf('session.') === 0) {
        collect[key] = currentState[key];
      }
      return collect;
    }, {});

    console.log('about to update score [deck]', {
      currentState,
      score: sessionState['session.tutorialScore'],
    });
    thunkApi.dispatch(setScore({ score: sessionState['session.tutorialScore'] }));

    // optimistically write to redux
    thunkApi.dispatch(updateExtrinsicState({ state: sessionState }));

    // in preview mode we don't talk to the server, so we're done
    if (isPreviewMode) {
      const allGood = results.every(({ result }) => result === null);
      // TODO: report actual errors?
      const status = allGood ? 'success' : 'error';
      return { result: status };
    }

    await writePageAttemptState(sectionSlug, resourceAttemptGuid, sessionState);
  },
);

const getSessionVisitHistory = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  isPreviewMode = false,
) => {
  let pageAttemptState: any;
  if (isPreviewMode) {
    const allState = getEnvState(defaultGlobalEnv);
    pageAttemptState = allState;
  } else {
    const { result } = await getPageAttemptState(sectionSlug, resourceAttemptGuid);
    pageAttemptState = result;
  }
  return Object.keys(pageAttemptState)
    .filter((key) => key.indexOf('session.visits.') === 0)
    .map((visitKey: string) => ({
      sequenceId: visitKey.replace('session.visits.', ''),
      visitCount: pageAttemptState[visitKey] as number,
    }));
};

export const navigateToNextActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToNextActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex = sequence.findIndex(
      (entry) => entry.custom.sequenceId === currentActivityId,
    );
    let nextSequenceEntry: SequenceEntry<SequenceEntryType> | null = null;
    let navError = '';
    if (currentIndex >= 0) {
      const nextIndex = currentIndex + 1;
      nextSequenceEntry = sequence[nextIndex];

      const parentBank = getParentBank(sequence, currentIndex);
      const visitHistory = await getSessionVisitHistory(
        sectionSlug,
        resourceAttemptGuid,
        isPreviewMode,
      );
      if (parentBank) {
        nextSequenceEntry = getNextQBEntry(sequence, parentBank, visitHistory);
      }
      while (nextSequenceEntry?.custom?.isBank || nextSequenceEntry?.custom?.isLayer) {
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isBank) {
          // this runs when we're about to enter a QB for the first time
          nextSequenceEntry = getNextQBEntry(
            sequence,
            nextSequenceEntry as SequenceEntry<SequenceBank>,
            visitHistory,
          );
        }
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isLayer) {
          // for layers if you try to navigate it should go to first child
          const firstChild = sequence.find(
            (entry) =>
              entry.custom?.layerRef ===
              (nextSequenceEntry as SequenceEntry<SequenceEntryType>).custom.sequenceId,
          );
          if (!firstChild) {
            navError = 'Target Layer has no children!';
          }
          nextSequenceEntry = firstChild;
        }
      }
      if (!nextSequenceEntry) {
        // If is end of sequence, return and set isEnd to truthy
        thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
        return;
      }
    } else {
      navError = `Current Activity ${currentActivityId} not found in sequence`;
    }
    if (navError) {
      throw new Error(navError);
    }

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextSequenceEntry?.custom.sequenceId }));
  },
);

export const navigateToPrevActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToPrevActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex = sequence.findIndex(
      (entry) => entry.custom.sequenceId === currentActivityId,
    );
    let previousEntry: SequenceEntry<SequenceEntryType> | null = null;
    let navError = '';
    if (currentIndex >= 0) {
      const nextIndex = currentIndex - 1;
      previousEntry = sequence[nextIndex];
      while (previousEntry && previousEntry?.custom?.isLayer) {
        const layerIndex = sequence.findIndex(
          (entry) => entry.custom.sequenceId === previousEntry?.custom?.sequenceId,
        );
        console.log({ currentIndex, layerIndex });

        previousEntry = sequence[layerIndex - 1];
      }
    } else {
      navError = `Current Activity ${currentActivityId} not found in sequence`;
    }
    if (navError) {
      throw new Error(navError);
    }
    thunkApi.dispatch(setCurrentActivityId({ activityId: previousEntry?.custom.sequenceId }));
  },
);

export const navigateToFirstActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToFirstActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const navigationSequences = selectNavigationSequence(sequence);
    if (!navigationSequences?.length) {
      console.warn(`Invalid sequence!`);
      return;
    }
    const nextActivityId = navigationSequences[0].custom.sequenceId;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToLastActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToLastActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToActivity`,
  async (sequenceId: string, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const desiredIndex = sequence.findIndex((s) => s.custom?.sequenceId === sequenceId);
    let nextSequenceEntry: SequenceEntry<SequenceEntryType> | null = null;
    let navError = '';
    const visitHistory = await getSessionVisitHistory(
      sectionSlug,
      resourceAttemptGuid,
      isPreviewMode,
    );
    if (desiredIndex >= 0) {
      nextSequenceEntry = sequence[desiredIndex];
      while (nextSequenceEntry?.custom?.isBank || nextSequenceEntry?.custom?.isLayer) {
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isBank) {
          // this runs when we're about to enter a QB for the first time
          nextSequenceEntry = getNextQBEntry(
            sequence,
            nextSequenceEntry as SequenceEntry<SequenceBank>,
            visitHistory,
          );
        }
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isLayer) {
          // for layers if you try to navigate it should go to first child
          const firstChild = sequence.find(
            (entry) =>
              entry.custom?.layerRef ===
              (nextSequenceEntry as SequenceEntry<SequenceEntryType>).custom.sequenceId,
          );

          if (!firstChild) {
            navError = 'Target Layer has no children!';
          }
          nextSequenceEntry = firstChild;
        }
      }
      if (!nextSequenceEntry) {
        // If is end of sequence, return and set isEnd to truthy
        thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
        return;
      }
    } else {
      navError = `Current Activity ${sequenceId} not found in sequence`;
    }
    if (navError) {
      throw new Error(navError);
    }

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextSequenceEntry?.custom.sequenceId }));
  },
);

interface ActivityAttemptMapping {
  attemptGuid: string;
  id: ResourceId;
}

export const loadActivities = createAsyncThunk(
  `${GroupsSlice}/deck/loadActivities`,
  async (activityAttemptMapping: ActivityAttemptMapping[], thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sectionSlug = selectSectionSlug(rootState);
    const isPreviewMode = selectPreviewMode(rootState);
    let results;
    if (isPreviewMode) {
      const activityIds = activityAttemptMapping.map((m) => m.id);
      results = await getBulkActivitiesForAuthoring(sectionSlug, activityIds);
    } else {
      const attemptGuids = activityAttemptMapping.map((m) => m.attemptGuid);
      results = await getBulkAttemptState(sectionSlug, attemptGuids);
    }
    const sequence = selectSequence(rootState);
    const activityTypes = selectActivityTypes(rootState);
    const activities = results.map((result) => {
      const resultActivityId = isPreviewMode ? result.id : result.activityId;
      const sequenceEntry = sequence.find((entry: any) => entry.activity_id === resultActivityId);
      if (!sequenceEntry) {
        console.warn(`Activity ${result.id} not found in the page model!`);
        return;
      }
      const attemptEntry = activityAttemptMapping.find((m) => m.id === sequenceEntry.activity_id);
      const activityType = activityTypes.find((t) => t.id === result.activityType);
      let partAttempts = result.partAttempts;
      if (isPreviewMode) {
        partAttempts = result.authoring.parts.map((p: any) => {
          return {
            attemptGuid: `preview_${guid()}`,
            attemptNumber: 1,
            dateEvaluated: null,
            feedback: null,
            outOf: null,
            partId: p.id,
            response: null,
            score: null,
          };
        });
      }
      const activityModel = {
        id: sequenceEntry.custom.sequenceId,
        resourceId: sequenceEntry.activity_id,
        content: isPreviewMode ? result.content : result.model,
        authoring: result.authoring || null,
        activityType,
        title: result.title,
        attemptGuid: attemptEntry?.attemptGuid || '',
      };
      const attemptState: ActivityState = {
        attemptGuid: attemptEntry?.attemptGuid || '',
        activityId: activityModel.resourceId,
        attemptNumber: result.attemptNumber || 1,
        dateEvaluated: result.dateEvaluated || null,
        score: result.score || null,
        outOf: result.outOf || null,
        parts: partAttempts,
        hasMoreAttempts: result.hasMoreAttempts || true,
        hasMoreHints: result.hasMoreHints || true,
      };
      return { model: activityModel, state: attemptState };
    });

    const models = activities.map((a) => a?.model);
    const states: ActivityState[] = activities
      .map((a) => a?.state)
      .filter((s) => s !== undefined) as ActivityState[];

    thunkApi.dispatch(loadActivityAttemptState({ attempts: states }));
    thunkApi.dispatch(setActivities({ activities: models }));

    // update the scripting environment with the latest activity state
    states.forEach((state) => {
      const hasResponse = state.parts.some((p) => p.response);
      /* console.log({ state, hasResponse }); */
      if (hasResponse) {
        // update globalEnv with the latest activity state
        const updateValues = state.parts.reduce((acc: any, p) => {
          if (!p.response) {
            return acc;
          }
          const inputs = Object.keys(p.response).reduce((acc2: any, key) => {
            acc2[p.response[key].path] = p.response[key].value;
            return acc2;
          }, {});
          return { ...acc, ...inputs };
        }, {});
        const assignScript = getAssignScript(updateValues);
        const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);
        if (scriptResult !== null) {
          console.warn('Error in state restore script', { state, scriptResult });
        }
        /* console.log('STATE RESTORE', { scriptResult }); */
      }
    });

    return { attempts: states, activities: models };
  },
);
