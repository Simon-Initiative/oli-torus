var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createAsyncThunk } from '@reduxjs/toolkit';
import { writePageAttemptState } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import { defaultGlobalEnv, evalScript, getAssignScript, } from '../../../../../../adaptivity/scripting';
import { setExtrinsicState, setResourceAttemptGuid } from '../../attempt/slice';
import { loadActivities, navigateToActivity, navigateToFirstActivity, } from '../../groups/actions/deck';
import { selectSequence } from '../../groups/selectors/deck';
import { LayoutType, selectCurrentGroup, setGroups } from '../../groups/slice';
import { loadPageState, PageSlice, selectResourceAttemptGuid } from '../slice';
export const loadInitialPageState = createAsyncThunk(`${PageSlice}/loadInitialPageState`, (params, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    const { dispatch, getState } = thunkApi;
    yield dispatch(loadPageState(params));
    const groups = params.content.model.filter((item) => item.type === 'group');
    const otherTypes = params.content.model.filter((item) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
        groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    // wait for this to resolve so that state will be updated
    yield dispatch(setGroups({ groups }));
    const currentGroup = selectCurrentGroup(getState());
    if ((currentGroup === null || currentGroup === void 0 ? void 0 : currentGroup.layout) === LayoutType.DECK) {
        // write initial session state (TODO: factor out elsewhere)
        const resourceAttemptGuid = selectResourceAttemptGuid(getState());
        dispatch(setResourceAttemptGuid({ guid: resourceAttemptGuid }));
        const sequence = selectSequence(getState());
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
        if (params.resourceAttemptState) {
            Object.assign(sessionState, params.resourceAttemptState);
        }
        // update scripting env with session state
        const assignScript = getAssignScript(sessionState, defaultGlobalEnv);
        const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);
        if (!params.previewMode) {
            yield writePageAttemptState(params.sectionSlug, resourceAttemptGuid, sessionState);
        }
        dispatch(setExtrinsicState({ state: sessionState }));
        let activityAttemptMapping;
        if (params.previewMode) {
            // need to load activities from the authoring api
            const activityIds = currentGroup.children.map((child) => child.activity_id);
            activityAttemptMapping = activityIds.map((id) => ({
                id,
                attemptGuid: `preview_${guid()}`,
            }));
        }
        else {
            activityAttemptMapping = Object.keys(params.activityGuidMapping).map((activityResourceId) => {
                return params.activityGuidMapping[activityResourceId];
            });
        }
        const { payload: { attempts }, } = yield dispatch(loadActivities(activityAttemptMapping));
        const shouldResume = attempts.some((attempt) => attempt.dateEvaluated !== null);
        if (shouldResume) {
            let resumeSequenceId = sequence[0].custom.sequenceId;
            if (params.resourceAttemptState && params.resourceAttemptState['session.resume']) {
                // resume from a previous attempt
                resumeSequenceId = params.resourceAttemptState['session.resume'];
            }
            else {
                // find the spot in the sequence that we should start from
                const resumeTarget = sequence.reduce((target, entry, index) => {
                    const sequenceAttempt = attempts.find((attempt) => attempt.activityId === entry.activity_id);
                    if ((sequenceAttempt === null || sequenceAttempt === void 0 ? void 0 : sequenceAttempt.dateEvaluated) !== null) {
                        // this actually isn't reliable because of pathed sequences
                        // so hopefully we had a session.resume from above
                        target = index + 1; // +1 because we are starting from the next item after the last completed one
                    }
                    return target;
                }, 0);
                resumeSequenceId = sequence[resumeTarget].custom.sequenceId;
            }
            dispatch(navigateToActivity(resumeSequenceId));
        }
        else {
            dispatch(navigateToFirstActivity());
        }
    }
}));
//# sourceMappingURL=loadInitialPageState.js.map