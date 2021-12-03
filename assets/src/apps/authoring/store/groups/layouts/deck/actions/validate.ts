import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice } from 'apps/authoring/store/app/slice';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';

export const validatePartIds = createAsyncThunk<any, any, any>(
  `${AppSlice}/validatePartIds`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();

    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);

    const errors: any[] = [];

    allActivities.forEach((activity) => {
      const duplicates = activity.authoring.parts.filter((ref: any) => {
        return activity.authoring.parts.filter((ref2: any) => ref2.id === ref.id).length > 1;
      });

      // also find problematic ids that are not alphanumeric or have underscores, colons, or spaces
      const problematicIds = activity.authoring.parts.filter((ref: any) => {
        return !ref.inherited && !/^[a-zA-Z0-9_\-: ]+$/.test(ref.id);
      });

      if (duplicates.length > 0 || problematicIds.length > 0) {
        const activitySequence = sequence.find((s) => s.resourceId === activity.id);
        const dupErrors = duplicates.map((dup: any) => {
          const dupSequence = sequence.find((s) => s.custom.sequenceId === dup.owner);
          return { ...dup, owner: dupSequence };
        });
        const problemIdErrors = problematicIds.map((problematicId: any) => {
          const problematicIdSequence = sequence.find(
            (s) => s.custom.sequenceId === problematicId.owner,
          );
          return { ...problematicId, owner: problematicIdSequence };
        });
        errors.push({
          activity: activitySequence,
          duplicates: dupErrors,
          problems: problemIdErrors,
        });
      }
    });

    return fulfillWithValue({ errors });
  },
);
