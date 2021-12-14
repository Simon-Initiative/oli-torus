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
import { bulkSaveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { isEqual } from 'lodash';
import { selectActivityById } from '../../../../../../delivery/store/features/activities/slice';
import { getSequenceLineage } from '../../../../../../delivery/store/features/groups/actions/sequence';
import { GroupsSlice, } from '../../../../../../delivery/store/features/groups/slice';
export const updateActivityPartInheritance = createAsyncThunk(`${GroupsSlice}/updateActivityPartInheritance`, (deck, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = getState();
    const activitiesToUpdate = [];
    deck.children.forEach((child) => {
        const lineage = getSequenceLineage(deck.children, child.custom.sequenceId);
        /* console.log('LINEAGE: ', { lineage, child }); */
        const combinedParts = lineage.reduce((collect, sequenceEntry) => {
            var _a;
            // load the activity record
            // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
            const activity = selectActivityById(rootState, sequenceEntry.resourceId);
            if (!activity) {
                // this is really an error
                return;
            }
            /* console.log('ACTIVITY" TO MAP: ', { activity }); */
            const activityParts = (_a = activity === null || activity === void 0 ? void 0 : activity.content) === null || _a === void 0 ? void 0 : _a.partsLayout.map((part) => {
                // TODO: response schema? & default response values?
                const partDefinition = {
                    id: part.id,
                    type: part.type,
                    inherited: activity.resourceId !== child.resourceId,
                    owner: sequenceEntry.custom.sequenceId,
                };
                return partDefinition;
            });
            const merged = [...collect, ...(activityParts || [])];
            return merged;
        }, []);
        /* console.log(`COMBINED ${child.activitySlug}`, { combinedParts }); */
        // since we are not updating the partsLayout but rather the parts, it should be OK
        // to update each activity *now*
        const childActivity = selectActivityById(rootState, child.resourceId);
        if (!childActivity) {
            return;
        }
        if (!isEqual(childActivity.authoring.parts, combinedParts)) {
            const clone = JSON.parse(JSON.stringify(childActivity));
            clone.authoring.parts = combinedParts;
            activitiesToUpdate.push(clone);
        }
    });
    if (activitiesToUpdate.length) {
        yield dispatch(bulkSaveActivity({ activities: activitiesToUpdate }));
    }
}));
//# sourceMappingURL=updateActivityPartInheritance.js.map