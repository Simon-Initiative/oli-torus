import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { CapiVariableTypes } from 'adaptivity/capi';
import {
  applyState,
  getValue,
  setConditionsWithExpression,
  templatizeText,
} from 'adaptivity/scripting';
import { handleValueExpression } from 'apps/delivery/layouts/deck/DeckLayoutFooter';
import {
  getBulkActivitiesForAuthoring,
  getBulkActivitiesForDelivery,
} from 'data/persistence/activity';
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
} from '../../../../../../adaptivity/scripting';
import { DeliveryRootState } from '../../../rootReducer';
import {
  selectCurrentActivity,
  selectCurrentActivityId,
  setActivities,
  setCurrentActivityId,
} from '../../activities/slice';
import {
  selectHistoryNavigationActivity,
  setInitPhaseComplete,
  setLessonEnd,
} from '../../adaptivity/slice';
import { loadActivityAttemptState, updateExtrinsicState } from '../../attempt/slice';
import {
  selectActivityTypes,
  selectIsInstructor,
  selectNavigationSequence,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectReviewMode,
  selectSectionSlug,
  setScore,
  setScreenIdleExpirationTime,
} from '../../page/slice';
import { GroupsSlice } from '../name';
import { selectCurrentActivityTree, selectSequence } from '../selectors/deck';
import { getNextQBEntry, getParentBank } from './navUtils';
import { SequenceBank, SequenceEntry, SequenceEntryType } from './sequence';

export const initializeActivity = createAsyncThunk(
  `${GroupsSlice}/deck/initializeActivity`,
  async (activityId: ResourceId, thunkApi) => {
    thunkApi.dispatch(setInitPhaseComplete(false));
    const rootState = thunkApi.getState() as DeliveryRootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const isReviewMode = selectReviewMode(rootState);
    const currentSequenceId = sequence.find((entry) => entry.activity_id === activityId)?.custom
      .sequenceId;
    if (!currentSequenceId) {
      throw new Error(`deck::initializeActivity - Activity ${activityId} not found in sequence!`);
    }
    const currentActivity = selectCurrentActivity(rootState);
    const currentActivityTree = selectCurrentActivityTree(rootState);

    const isHistoryMode = selectHistoryNavigationActivity(rootState);

    /* console.log('CAT', { currentActivityTree, currentActivity }); */
    // bind all parent parts to current activity
    if (currentActivityTree && currentActivityTree?.length > 1) {
      const syncOps: ApplyStateOperation[] = [];
      for (let i = 0; i < currentActivityTree.length - 1; i++) {
        const ancestor = currentActivityTree[i];
        for (let p = 0; p < (ancestor.content?.partsLayout || []).length; p++) {
          const part = ancestor.content!.partsLayout[p];
          // get the adaptivity variables for the part
          const Klass = customElements.get(part.type);
          if (Klass) {
            const instance = new Klass() as any;
            if (instance.getAdaptivitySchema) {
              const variables = await instance.getAdaptivitySchema({ currentModel: part.custom });
              // for each key in variables create a ApplyStateOperation with "anchor to" for the current activity
              for (const key in variables) {
                const target = `${currentSequenceId}|stage.${part.id}.${key}`;
                const operator = 'anchor to';
                const value = `${ancestor.id}|stage.${part.id}.${key}`;
                // we don't need to apply binding if both the target & value are same
                if (target !== value) {
                  const op: ApplyStateOperation = {
                    target,
                    operator,
                    value,
                    type: variables[key],
                  };
                  syncOps.push(op);
                }
              }
            }
          }
        }
      }
      /* console.log('SYNC OPS', syncOps); */
      if (syncOps.length > 0) {
        await bulkApplyState(syncOps);
      }
    }

    const resumeTarget: ApplyStateOperation = {
      target: `session.resume`,
      operator: '=',
      value: currentSequenceId,
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
    const isResumeMode = !!getValue('session.isResumeMode', defaultGlobalEnv);
    const ongoingAttemptNumber = getValue('session.attemptNumber', defaultGlobalEnv);
    const defaultActivityStartAttemptNumber = 1;
    const attemptNumberOp: ApplyStateOperation = {
      target: 'session.attemptNumber',
      operator: '=',
      value:
        isResumeMode && ongoingAttemptNumber
          ? ongoingAttemptNumber
          : defaultActivityStartAttemptNumber,
    };
    const targettedAttemptNumberOp: ApplyStateOperation = {
      target: `${currentSequenceId}|session.attemptNumber`,
      operator: '=',
      value:
        isResumeMode && ongoingAttemptNumber
          ? ongoingAttemptNumber
          : defaultActivityStartAttemptNumber,
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

    if (isHistoryMode) {
      const targetIsResumeModeOp: ApplyStateOperation = {
        target: 'session.isResumeMode',
        operator: '=',
        value: false,
      };
      applyState(targetIsResumeModeOp, defaultGlobalEnv);
    }
    const sessionOps = [
      resumeTarget,
      timeStartOp,
      timeOnQuestion,
      timeExceededOp,
      attemptNumberOp,
      targettedAttemptNumberOp,
      tutorialScoreOp,
      // must come *after* the tutorial score op
      currentScoreOp,
    ];
    const trackingStampKey = `session.visitTimestamps.${currentSequenceId}`;
    // looks like SS captures the date when we leave the page but it should
    // show in the history as soon as we visit but it does not show the timestamp
    // so we will capture the time on trigger check
    const targetVisitTimeStampOp: ApplyStateOperation = {
      target: trackingStampKey,
      operator: '=',
      value: 0,
    };
    if (!isReviewMode && !isHistoryMode) {
      sessionOps.push(targetVisitTimeStampOp);
    }
    // init state is always "local" but the parts may come from parent layers
    // in that case they actually need to be written to the parent layer values
    const initState = currentActivity?.content?.custom?.facts || [];
    const globalizedInitState = initState.map((s: any) => {
      // do this first so that *all* can have their values processed
      let modifiedValue = handleValueExpression(currentActivityTree, s.value, s.operator);
      modifiedValue =
        typeof modifiedValue === 'string'
          ? templatizeText(modifiedValue, {}, defaultGlobalEnv, false, true, s.target)
          : modifiedValue;

      if (s.target.indexOf('stage.') !== 0) {
        return { ...s, value: modifiedValue };
      }
      const [, targetPart] = s.target.split('.');
      const ownerActivity = currentActivityTree?.find(
        (activity) => !!(activity.content?.partsLayout || []).find((p: any) => p.id === targetPart),
      );
      if (s.type === CapiVariableTypes.MATH_EXPR) {
        return { ...s, target: `${ownerActivity!.id}|${s.target}` };
      }

      if (!ownerActivity) {
        // shouldn't happen, but ignore I guess
        return { ...s, value: modifiedValue };
      }
      return { ...s, target: `${ownerActivity.id}|${s.target}`, value: modifiedValue };
    });

    const stateOps = isHistoryMode ? globalizedInitState : [...sessionOps, ...globalizedInitState];

    const results = bulkApplyState(stateOps, defaultGlobalEnv);
    /* console.log('INIT STATE', { results, globalizedInitState, defaultGlobalEnv }); */

    const applyStateHasErrors = results.some((r) => r.result !== null);
    if (applyStateHasErrors) {
      console.warn('[INIT STATE] applyState has errors', results);
    }
    // now that the scripting env should be up to date, need to update attempt state in redux and server
    const currentState = getEnvState(defaultGlobalEnv);

    const sessionState = Object.keys(currentState).reduce((collect: any, key) => {
      if (key.indexOf('session.') !== -1) {
        collect[key] = currentState[key];
      }
      return collect;
    }, {});

    /* console.log('about to update score [deck]', {
      currentState,
      score: sessionState['session.tutorialScore'],
    }); */
    const tutScore = sessionState['session.tutorialScore'] || 0;
    const curScore = sessionState['session.currentQuestionScore'] || 0;
    thunkApi.dispatch(setScore({ score: tutScore + curScore }));

    // optimistically write to redux
    thunkApi.dispatch(updateExtrinsicState({ state: sessionState }));

    // in preview mode we don't talk to the server, so we're done
    // if we're in history mode we shouldn't be writing anything
    if (isPreviewMode || isHistoryMode) {
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

export const findNextSequenceId = createAsyncThunk(
  `${GroupsSlice}/deck/findNextSequenceId`,
  async (sequenceId: string, thunkApi) => {
    const rootState = thunkApi.getState() as DeliveryRootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    let nextSequenceEntry: SequenceEntry<SequenceEntryType> | null = null;
    let navError = '';

    const visitHistory = await getSessionVisitHistory(
      sectionSlug,
      resourceAttemptGuid,
      isPreviewMode,
    );

    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex =
      sequenceId === 'next'
        ? sequence.findIndex((entry) => entry.custom.sequenceId === currentActivityId)
        : sequence.findIndex((s) => s.custom?.sequenceId === sequenceId);
    if (currentIndex >= 0) {
      const nextIndex = sequenceId === 'next' ? currentIndex + 1 : currentIndex;
      nextSequenceEntry = sequence[nextIndex];
      if (sequenceId === 'next') {
        const parentBank = getParentBank(sequence, currentIndex);
        if (parentBank) {
          nextSequenceEntry = getNextQBEntry(sequence, parentBank, visitHistory);
        }
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
          nextSequenceEntry = firstChild || null;
        }
      }
      if (!nextSequenceEntry) {
        // If is end of sequence, return and set isEnd to truthy
        thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
        return;
      }
    } else {
      navError =
        sequenceId === 'next'
          ? `Current Activity ${currentActivityId} not found in sequence`
          : `deck::navigateToActivity - Current Activity ${sequenceId} not found in sequence`;
    }

    if (navError) {
      throw new Error(navError);
    }
    return nextSequenceEntry?.custom.sequenceId;
  },
);

export const navigateToNextActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToNextActivity`,
  async (_, thunkApi) => {
    const { payload: nextActivityId } = await thunkApi.dispatch(findNextSequenceId('next'));
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToPrevActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToPrevActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as DeliveryRootState;
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
        /* console.log({ currentIndex, layerIndex }); */

        previousEntry = sequence[layerIndex - 1];
      }
    } else {
      navError = `deck::navigateToPrevActivity - Current Activity ${currentActivityId} not found in sequence`;
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
    const rootState = thunkApi.getState() as DeliveryRootState;
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
    const nextActivityId = 1;
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToActivity`,
  async (sequenceId: string, thunkApi) => {
    console.log({ sequenceId });

    const { payload: nextActivityId } = await thunkApi.dispatch(findNextSequenceId(sequenceId));
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const finalizeLesson = createAsyncThunk(
  `${GroupsSlice}/deck/finalizeLesson`,
  async (_, thunkApi) => {
    thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
  },
);

interface ActivityAttemptMapping {
  attemptGuid: string;
  id: ResourceId;
}

export const loadActivities = createAsyncThunk(
  `${GroupsSlice}/deck/loadActivities`,
  async (activityAttemptMapping: ActivityAttemptMapping[], thunkApi) => {
    //reset the screen Idle Time
    thunkApi.dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
    const rootState = thunkApi.getState() as DeliveryRootState;
    const sectionSlug = selectSectionSlug(rootState);
    const isPreviewMode = selectPreviewMode(rootState);
    const isInstructor = selectIsInstructor(rootState);
    let results;
    if (isPreviewMode) {
      const activityIds = activityAttemptMapping.map((m) => m.id);

      results = isInstructor
        ? await getBulkActivitiesForDelivery(sectionSlug, activityIds, isPreviewMode)
        : await getBulkActivitiesForAuthoring(sectionSlug, activityIds);
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
        dateSubmitted: result.dateSubmitted || null,
        score: result.score || null,
        outOf: result.outOf || null,
        parts: partAttempts,
        hasMoreAttempts: result.hasMoreAttempts || true,
        hasMoreHints: result.hasMoreHints || true,
        groupId: null,
      };
      //To improve the performance, when a lesson is opened in authoring, we generate a list of variables that contains expression and needs evaluation
      // we stored them in conditionsNeedEvaluation in activity.content.custom.conditionsNeedEvaluation. When this function is called
      // we only process variables that is present in conditionsNeedEvaluation array and ignore others.
      // Reason for storing it in activityModel.content.custom.conditionsRequiredEvaluation is because,
      //in student mode, activityModel.authoring is not available in delivery
      if (activityModel.content.custom.conditionsRequiredEvaluation?.length) {
        setConditionsWithExpression(activityModel.content.custom.conditionsRequiredEvaluation);
      }

      return { model: activityModel, state: attemptState };
    });

    const models = activities.map((a) => a?.model);
    const states: ActivityState[] = activities
      .map((a) => a?.state)
      .filter((s) => s !== undefined) as ActivityState[];

    // when resuming a session, we want to reset the current part attempt values
    const shouldResume = states.some((attempt: any) => attempt.dateEvaluated !== null);
    if (shouldResume) {
      const targetIsResumeModeOp: ApplyStateOperation = {
        target: 'session.isResumeMode',
        operator: '=',
        value: true,
      };
      applyState(targetIsResumeModeOp, defaultGlobalEnv);
      const snapshot = getEnvState(defaultGlobalEnv);
      const resumeId = snapshot['session.resume'];
      const currentResumeActivityAttempt = models.filter((model: any) => model.id === resumeId);
      if (currentResumeActivityAttempt?.length) {
        const currentActivityAttempt = currentResumeActivityAttempt[0];
        states.forEach((state) => {
          if (state.attemptGuid === currentResumeActivityAttempt[0]?.attemptGuid) {
            state.parts.forEach((part) => {
              const isIFramePartComponent = currentActivityAttempt?.content?.partsLayout?.filter(
                (customPart: any) =>
                  customPart.id === part.partId && customPart.type === 'janus-capi-iframe',
              );
              //Reset the attempt for iFrame parts only
              if (isIFramePartComponent?.length) {
                part.response = [];
              }
            });
          }
        });
      }
    }

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
        const assignScript = getAssignScript(updateValues, defaultGlobalEnv);
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
