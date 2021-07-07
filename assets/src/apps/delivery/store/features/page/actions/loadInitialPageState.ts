import { createAsyncThunk } from '@reduxjs/toolkit';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import {
  defaultGlobalEnv,
  evalScript,
  getAssignScript,
} from '../../../../../../adaptivity/scripting';
import { RootState } from '../../../rootReducer';
import { setExtrinsicState, setResourceAttemptGuid } from '../../attempt/slice';
import {
  loadActivities,
  navigateToActivity,
  navigateToFirstActivity,
} from '../../groups/actions/deck';
import { selectSequence } from '../../groups/selectors/deck';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import { loadPageState, PageSlice, PageState, selectResourceAttemptGuid } from '../slice';

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

      if (params.resourceAttemptState) {
        Object.assign(sessionState, params.resourceAttemptState);
      }

      // update scripting env with session state
      const assignScript = getAssignScript(sessionState);
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
        let resumeSequenceId = sequence[0].custom.sequenceId;
        if (params.resourceAttemptState && params.resourceAttemptState['session.resume']) {
          // resume from a previous attempt
          resumeSequenceId = params.resourceAttemptState['session.resume'];
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
        dispatch(navigateToActivity(resumeSequenceId));
      } else {
        dispatch(navigateToFirstActivity());
      }
    }
  },
);
