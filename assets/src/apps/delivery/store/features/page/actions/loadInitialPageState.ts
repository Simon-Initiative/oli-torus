import { createAsyncThunk } from '@reduxjs/toolkit';
import { readGlobalUserState } from 'data/persistence/extrinsic';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import {
  defaultGlobalEnv,
  evalScript,
  getAssignScript,
  getEnvState,
} from '../../../../../../adaptivity/scripting';
import { RootState } from '../../../rootReducer';
import { setHistoryNavigationTriggered } from '../../adaptivity/slice';
import { setExtrinsicState, setResourceAttemptGuid } from '../../attempt/slice';
import {
  loadActivities,
  navigateToActivity,
  navigateToFirstActivity,
} from '../../groups/actions/deck';
import { selectSequence } from '../../groups/selectors/deck';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import PageSlice from '../name';
import { loadPageState, PageState, selectResourceAttemptGuid } from '../slice';

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
    // wait for this to resolve so that state will be updated
    await dispatch(setGroups({ groups }));

    const currentGroup = selectCurrentGroup(getState() as RootState);
    if (currentGroup?.layout === LayoutType.DECK) {
      // write initial session state (TODO: factor out elsewhere)
      const resourceAttemptGuid = selectResourceAttemptGuid(getState() as RootState);
      dispatch(setResourceAttemptGuid({ guid: resourceAttemptGuid }));
      const sequence = selectSequence(getState() as RootState);
      const sessionState = sequence.reduce((acc, entry) => {
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
      if (params.content.custom?.everApps) {
        const everAppIds = params.content.custom.everApps.map((everApp: any) => everApp.id);
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
        Object.assign(sessionState, params.resourceAttemptState);
      }

      // update scripting env with session state
      const assignScript = getAssignScript(sessionState, defaultGlobalEnv);
      const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);

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
      if (shouldResume) {
        // state should be all up to date by now
        const snapshot = getEnvState(defaultGlobalEnv);
        const visitHistory = Object.keys(snapshot)
          .filter((key: string) => key.indexOf('session.visitTimestamps.') === 0)
          .map((entry) => ({ id: entry.split('.')[2], ts: snapshot[entry] }))
          .sort((a, b) => b.ts - a.ts);
        const resumeId = snapshot['session.resume'];

        /* console.log('VISIT HISTORY', { visitHistory, resumeId, snapshot }); */

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
        // need to check the visitHistory to see if the resumeSequenceId is in there and is NOT the latest, then we need to set history mode to true
        const resumeHistoryIndex = visitHistory.findIndex((entry) => entry.id === resumeSequenceId);
        if (resumeHistoryIndex > 0) {
          /* console.log('RESUMING IN HISTORY MODE', { resumeHistoryIndex, visitHistory }); */
          dispatch(setHistoryNavigationTriggered({ historyModeNavigation: true }));
        }
        /* console.log('RESUME SEQUENCE ID', { resumeSequenceId }); */
        dispatch(navigateToActivity(resumeSequenceId));
      } else {
        dispatch(navigateToFirstActivity());
      }
    }
  },
);
