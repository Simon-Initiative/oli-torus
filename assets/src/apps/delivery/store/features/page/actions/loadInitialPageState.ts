import { createAsyncThunk } from '@reduxjs/toolkit';
import { readGlobalUserState } from 'data/persistence/extrinsic';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import {
  defaultGlobalEnv,
  evalAssignScript,
  evalScript,
  getAssignScript,
  getEnvState,
} from '../../../../../../adaptivity/scripting';
import { DeliveryRootState } from '../../../rootReducer';
import { setExtrinsicState, setResourceAttemptGuid } from '../../attempt/slice';
import {
  loadActivities,
  navigateToActivity,
  navigateToFirstActivity,
} from '../../groups/actions/deck';
import { selectSequence } from '../../groups/selectors/deck';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import PageSlice from '../name';
import { PageState, loadPageState, selectResourceAttemptGuid, selectReviewMode } from '../slice';

export const loadInitialPageState = createAsyncThunk(
  `${PageSlice}/loadInitialPageState`,
  async (params: PageState, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    await dispatch(loadPageState(params));

    const groups = params.content.model.filter((item: any) => item.type === 'group');
    const otherTypes = params.content.model.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    const isReviewMode = selectReviewMode(getState() as DeliveryRootState);
    // wait for this to resolve so that state will be updated
    await dispatch(setGroups({ groups }));
    const currentGroup = selectCurrentGroup(getState() as DeliveryRootState);
    if (currentGroup?.layout === LayoutType.DECK) {
      // write initial session state (TODO: factor out elsewhere)
      const resourceAttemptGuid = selectResourceAttemptGuid(getState() as DeliveryRootState);
      dispatch(setResourceAttemptGuid({ guid: resourceAttemptGuid }));
      const sequence = selectSequence(getState() as DeliveryRootState);
      const sessionState: any = sequence.reduce((acc: any, entry) => {
        acc[`session.visits.${entry.custom.sequenceId}`] = 0;
        return acc;
      }, {});
      // init variables so add ops can function
      sessionState['session.tutorialScore'] = 0;
      sessionState['session.currentQuestionScore'] = 0;
      sessionState['session.timeStartQuestion'] = 0;
      sessionState['session.attemptNumber'] = 0;
      sessionState['session.timeOnQuestion'] = 0;

      // Sets up Current Active Everapp to None
      sessionState['app.active'] = 'none';
      // read all user state for the assigned everapps into the session state
      /* console.log('INIT PAGE', params); */
      const everApps = params.content.custom?.everApps;
      let everAppIds = [];
      if(everApps){
         everAppIds = params.content.custom.everApps.map((everApp: any) => everApp.id);
      }
      if (everAppIds && Array.isArray(everAppIds)) {
        const userState = await readGlobalUserState(everAppIds, params.previewMode);
        if (typeof userState === 'object') {
          const everAppState = Object.keys(userState).reduce((acc: any, key) => {
            const subState = userState[key];
            if (typeof subState !== 'object') {
              return acc;
            }
            Object.keys(subState).forEach((subKey) => {
              acc[`app.${key}.${subKey}`] = subState[subKey];
            });
            return acc;
          }, {});
          /* console.log('EVER APP STATE', { userState, everAppIds, everAppState }); */
          Object.assign(sessionState, everAppState);
        }
      }

      if (params.resourceAttemptState) {
        //EverApp state is already up-to date and merged with sessionState at this point. We should not update the Ever App state with params.resourceAttemptState
        const partAttemptVariables = Object.keys(params.resourceAttemptState).filter(
          (key) => !key.startsWith('app.'),
        );
        const resourceAttemptStateWithoutEverAppState = partAttemptVariables.reduce(
          (acc: Record<string, any>, entry) => {
            acc[entry] = params.resourceAttemptState[entry];
            return acc;
          },
          {},
        );
        Object.assign(sessionState, resourceAttemptStateWithoutEverAppState);
      }

      // update scripting env with session state
      const assignScript = getAssignScript(sessionState, defaultGlobalEnv);
      const { result: _scriptResult } = evalScript(assignScript, defaultGlobalEnv);

      if (!params.previewMode) {
        await writePageAttemptState(params.sectionSlug, resourceAttemptGuid, sessionState);
      }

      dispatch(setExtrinsicState({ state: sessionState }));

      let activityAttemptMapping;
      if (params.previewMode) {
        // need to load activities from the authoring api
        const activityIds = currentGroup.children.map((child: any) => child.activity_id);
        activityAttemptMapping = activityIds.map((id) => ({
          id,
          attemptGuid: `preview_${guid()}`,
        }));
      } else {
        activityAttemptMapping = Object.keys(params.activityGuidMapping).map(
          (activityResourceId) => {
            return params.activityGuidMapping[activityResourceId];
          },
        );
      }
      const {
        payload: { attempts },
      }: any = await dispatch(loadActivities(activityAttemptMapping));

      const shouldResume = attempts.some((attempt: any) => attempt.dateEvaluated !== null);
      if (shouldResume && !isReviewMode) {
        // state should be all up to date by now
        const snapshot = getEnvState(defaultGlobalEnv);
        const resumeId = snapshot['session.resume'];
        /* console.log('RESUMING!: ', { attempts, resumeId }); */
        // if we are resuming, then session.tutorialScore should be set based on the total attempt.score
        // and session.currentQuestionScore should be 0
        const totalScore = attempts.reduce((acc: number, attempt: any) => {
          acc += attempt.score;
          return acc;
        }, 0);
        evalAssignScript(
          { 'session.tutorialScore': totalScore, 'session.currentQuestionScore': 0 },
          defaultGlobalEnv,
        );
        const updateSessionState = clone(sessionState);
        updateSessionState['session.tutorialScore'] = totalScore;
        updateSessionState['session.currentQuestionScore'] = 0;
        if (!params.previewMode) {
          await writePageAttemptState(params.sectionSlug, resourceAttemptGuid, updateSessionState);
        }

        let resumeSequenceId = sequence[0].custom.sequenceId;
        if (resumeId) {
          // resume from a previous attempt
          resumeSequenceId = resumeId;
        } else {
          // find the spot in the sequence that we should start from
          const resumeTarget = sequence.reduce((target, entry, index) => {
            const sequenceAttempt = attempts.find(
              (attempt: any) => attempt.activityId === entry.activity_id,
            );
            if (sequenceAttempt?.dateEvaluated !== null) {
              // this actually isn't reliable because of pathed sequences
              // so hopefully we had a session.resume from above
              target = index + 1; // +1 because we are starting from the next item after the last completed one
            }
            return target;
          }, 0);
          resumeSequenceId = sequence[resumeTarget].custom.sequenceId;
        }
        /* console.log('RESUME SEQUENCE ID', { resumeSequenceId }); */
        dispatch(navigateToActivity(resumeSequenceId));
      } else {
        dispatch(navigateToFirstActivity());
      }
    }
  },
);
