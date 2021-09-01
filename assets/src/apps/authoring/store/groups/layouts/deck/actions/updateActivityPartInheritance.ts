import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityUpdate, BulkActivityUpdate, bulkEdit, edit } from 'data/persistence/activity';
import { isEqual } from 'lodash';
import {
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import { getSequenceLineage } from '../../../../../../delivery/store/features/groups/actions/sequence';
import {
  DeckLayoutGroup,
  GroupsSlice,
} from '../../../../../../delivery/store/features/groups/slice';
import { acquireEditingLock, releaseEditingLock } from '../../../../app/actions/locking';
import { selectProjectSlug } from '../../../../app/slice';
import { selectResourceId } from '../../../../page/slice';

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
        const activity = selectActivityById(rootState, sequenceEntry.resourceId!);
        if (!activity) {
          // this is really an error
          return;
        }
        /* console.log('ACTIVITY" TO MAP: ', { activity }); */
        const activityParts = activity?.content?.partsLayout.map((part: any) => {
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
      await dispatch(acquireEditingLock());
      /* console.log('UPDATE: ', { activitiesToUpdate }); */
      dispatch(upsertActivities({ activities: activitiesToUpdate }));
      // TODO: write to server
      const projectSlug = selectProjectSlug(rootState);
      const resourceId = selectResourceId(rootState);
      // in lieu of bulk edit
      const updates: BulkActivityUpdate[] = activitiesToUpdate.map((activity) => {
        const changeData: BulkActivityUpdate = {
          title: activity.title,
          objectives: activity.objectives,
          content: activity.content,
          authoring: activity.authoring,
          resource_id: resourceId,
        };
        return changeData;
      });
      await bulkEdit(projectSlug, resourceId, updates);
      await dispatch(releaseEditingLock());
      return;
    }
  },
);
