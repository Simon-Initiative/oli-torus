import { createAsyncThunk } from '@reduxjs/toolkit';
import { bulkSaveActivity } from 'apps/authoring/store/activities/actions/saveActivity';
import { selectProjectSlug, selectReadOnly } from 'apps/authoring/store/app/slice';
import { selectResourceId } from 'apps/authoring/store/page/slice';
import { BulkActivityUpdate, bulkEdit } from 'data/persistence/activity';
import { isEqual } from 'lodash';
import { selectActivityById } from '../../../../../../delivery/store/features/activities/slice';
import { getSequenceLineage } from '../../../../../../delivery/store/features/groups/actions/sequence';
import { DeckLayoutGroup } from '../../../../../../delivery/store/features/groups/slice';
import GroupsSlice from '../../../../../../delivery/store/features/groups/name';

export const updateActivityPartInheritance = createAsyncThunk(
  `${GroupsSlice}/updateActivityPartInheritance`,
  async (deck: DeckLayoutGroup, { dispatch, getState }) => {
    const rootState = getState() as any;
    const isReadOnlyMode = selectReadOnly(rootState);

    const activitiesToUpdate: any[] = [];
    deck.children.forEach((child: any) => {
      const lineage = getSequenceLineage(deck.children, child.custom.sequenceId);

      /* console.log('LINEAGE: ', { lineage, child }); */
      const combinedParts = lineage
        .reduce((collect: any, sequenceEntry) => {
          // load the activity record
          // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
          const activity = selectActivityById(rootState, sequenceEntry.resourceId!);
          if (!activity) {
            // this is really an error
            return;
          }
          /* console.log('ACTIVITY" TO MAP: ', { activity }); */
          const activityParts = activity?.content?.partsLayout.map((part: any) => {
            const partDefinition = {
              id: part.id,
              type: part.type,
              inherited: activity.resourceId !== child.resourceId,
              owner: sequenceEntry.custom.sequenceId,
            };

            // for now exclude janus-text-flow and janus-image
            // TODO: base on adaptivity flag?
            if (part.type === 'janus-text-flow' || part.type === 'janus-image') {
              return null;
            }

            return partDefinition;
          });
          const merged = [...collect, ...(activityParts || [])];

          return merged;
        }, [])
        .filter((part: any) => part);

      // an activity must have at least one part, if it doesn't, then create a default one
      if (combinedParts.length === 0) {
        combinedParts.push({
          id: '__default',
          type: 'janus-text-flow',
          inherited: false,
          owner: child.custom.sequenceId,
        });
      }

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
      /* console.log('ACTIVITIES TO UPDATE: ', { activitiesToUpdate }); */
      await dispatch(bulkSaveActivity({ activities: activitiesToUpdate, undoable: true }));
      if (!isReadOnlyMode) {
        const projectSlug = selectProjectSlug(rootState);
        const pageResourceId = selectResourceId(rootState);
        const updates: BulkActivityUpdate[] = activitiesToUpdate.map((activity) => {
          const changeData: BulkActivityUpdate = {
            title: activity.title,
            objectives: activity.objectives,
            content: activity.content,
            authoring: activity.authoring,
            resource_id: activity.resourceId,
          };
          return changeData;
        });
        await bulkEdit(projectSlug, pageResourceId, updates);
      }
    }
  },
);
