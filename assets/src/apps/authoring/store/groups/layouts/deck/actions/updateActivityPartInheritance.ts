import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import { getSequenceLineage } from '../../../../../../delivery/store/features/groups/actions/sequence';
import {
  DeckLayoutGroup,
  GroupsSlice,
} from '../../../../../../delivery/store/features/groups/slice';

export const updateActivityPartInheritance = createAsyncThunk(
  `${GroupsSlice}/updateActivityPartInheritance`,
  async (deck: DeckLayoutGroup, { dispatch, getState }) => {
    const rootState = getState() as any;
    const activitiesToUpdate: any[] = [];
    deck.children.forEach((child: any) => {
      const lineage = getSequenceLineage(deck.children, child.custom.sequenceId);

      /* console.log('LINEAGE: ', { lineage, child }); */
      const combinedParts = lineage.reduce((collect: any, sequenceEntry) => {
        // load the activity record
        const activity = selectActivityById(rootState, sequenceEntry.activitySlug as string);
        if (!activity) {
          // this is really an error
          return;
        }
        const activityParts = activity.model.partsLayout.map((part: any) => {
          // TODO: response schema? & default response values?
          const partDefinition = {
            id: part.id,
            type: part.type,
            inherited: activity.activitySlug !== child.activitySlug,
            owner: sequenceEntry.custom.sequenceId,
          };

          return partDefinition;
        });
        const merged = [...collect, ...activityParts];

        return merged;
      }, []);

      /* console.log(`COMBINED ${child.activitySlug}`, { combinedParts }); */
      // since we are not updating the partsLayout but rather the parts, it should be OK
      // to update each activity *now*
      const childActivity = selectActivityById(rootState, child.activitySlug);
      if (!childActivity) {
        return;
      }
      if (JSON.stringify(childActivity.model.authoring.parts) !== JSON.stringify(combinedParts)) {
        const clone = JSON.parse(JSON.stringify(childActivity));
        clone.model.authoring.parts = combinedParts;
        activitiesToUpdate.push(clone);
      }
    });
    if (activitiesToUpdate.length) {
      console.log('UPDATE: ', { activitiesToUpdate });
      dispatch(upsertActivities({ activities: activitiesToUpdate }));
      // TODO: write to server
    }
  },
);
