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
import { bulkEdit, edit } from 'data/persistence/activity';
import { ActivitiesSlice, upsertActivities, upsertActivity, } from '../../../../delivery/store/features/activities/slice';
import { selectProjectSlug, selectReadOnly } from '../../app/slice';
import { selectResourceId } from '../../page/slice';
export const saveActivity = createAsyncThunk(`${ActivitiesSlice}/saveActivity`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const { activity } = payload;
    const rootState = getState();
    const projectSlug = selectProjectSlug(rootState);
    const resourceId = selectResourceId(rootState);
    const isReadOnlyMode = selectReadOnly(rootState);
    const changeData = {
        title: activity.title,
        objectives: activity.objectives,
        content: Object.assign(Object.assign({}, activity.content), { authoring: activity.authoring }),
        tags: activity.tags,
    };
    if (!isReadOnlyMode) {
        /* console.log('going to save acivity: ', { changeData, activity }); */
        const editResults = yield edit(projectSlug, resourceId, activity.resourceId, changeData, false);
        /* console.log('EDIT SAVE RESULTS', { editResults }); */
    }
    yield dispatch(upsertActivity({ activity }));
    return;
}));
export const bulkSaveActivity = createAsyncThunk(`${ActivitiesSlice}/bulkSaveActivity`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const { activities } = payload;
    const rootState = getState();
    const projectSlug = selectProjectSlug(rootState);
    const pageResourceId = selectResourceId(rootState);
    const isReadOnlyMode = selectReadOnly(rootState);
    dispatch(upsertActivities({ activities }));
    if (!isReadOnlyMode) {
        const updates = activities.map((activity) => {
            const changeData = {
                title: activity.title,
                objectives: activity.objectives,
                content: activity.content,
                authoring: activity.authoring,
                resource_id: activity.resourceId,
            };
            return changeData;
        });
        yield bulkEdit(projectSlug, pageResourceId, updates);
    }
    return;
}));
//# sourceMappingURL=saveActivity.js.map