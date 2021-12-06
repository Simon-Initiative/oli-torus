import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice } from 'apps/authoring/store/app/slice';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';

// generate a suggestion for the id based on the input id that is only alpha numeric or underscores
const generateSuggestion = (id: string, dupBlacklist: string[] = []): string => {
  let newId = id.replace(/[^a-zA-Z0-9_]/g, '');
  if (dupBlacklist.includes(newId)) {
    // if the last character of the id is already a number, increment it, otherwise add 1
    const lastChar = newId.slice(-1);
    if (lastChar.match(/[0-9]/)) {
      const newLastChar = parseInt(lastChar, 10) + 1;
      newId = `${newId.slice(0, -1)}${newLastChar}`;
    } else {
      newId = `${newId}1`;
    }
    return generateSuggestion(newId, dupBlacklist);
  }
  return newId;
};

export const validatePartIds = createAsyncThunk<any, any, any>(
  `${AppSlice}/validatePartIds`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();

    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);
    const hierarchy = getHierarchy(sequence);

    /* console.log('validatePartIds', { allActivities }); */

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

        // id blacklist should include all parent ids, and all children ids
        const lineageBlacklist = getSequenceLineage(sequence, activitySequence.custom.sequenceId)
          .map((s) => allActivities.find((a) => a.id === s.resourceId))
          .map((a) => a?.authoring.parts.map((ref: any) => ref.id))
          .reduce((acc, cur) => acc.concat(cur), []);
        const hierarchyItem = findInHierarchy(hierarchy, activitySequence.custom.sequenceId);
        const childrenBlackList: string[] = flattenHierarchy(hierarchyItem?.children ?? [])
          .map((s) => allActivities.find((a) => a.id === s.resourceId))
          .map((a) => a?.authoring.parts.map((ref: any) => ref.id))
          .reduce((acc, cur) => acc.concat(cur), []);
        console.log('blacklists: ', { lineageBlacklist, childrenBlackList });
        const testBlackList = Array.from(new Set([...lineageBlacklist, ...childrenBlackList]));

        const dupErrors = duplicates.map((dup: any) => {
          const dupSequence = sequence.find((s) => s.custom.sequenceId === dup.owner);
          return {
            ...dup,
            owner: dupSequence,
            suggestedFix: generateSuggestion(dup.id, testBlackList),
          };
        });
        const problemIdErrors = problematicIds.map((problematicId: any) => {
          const problematicIdSequence = sequence.find(
            (s) => s.custom.sequenceId === problematicId.owner,
          );
          return {
            ...problematicId,
            owner: problematicIdSequence,
            suggestedFix: generateSuggestion(problematicId.id, testBlackList),
          };
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
