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
import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';

export interface DiagnosticProblem {
  owner: unknown;
  type: string;
  // getSuggestion: () => any;
  // getSolution: (resolution: unknown) => () => void;
  suggestedFix: string;
  item: any;
}
export interface DiagnosticError {
  activity: unknown;
  problems: DiagnosticProblem[];
}

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

const mapErrorProblems = (list: any[], type: string, seq: any[], blackList: any[]) =>
  list.map((item: any) => {
    const problemSequence = seq.find((s) => s.custom.sequenceId === item.owner);
    return {
      type,
      item,
      owner: problemSequence || item.owner,
      suggestedFix: generateSuggestion(item.id, blackList),
    };
  });

export const validators = [
  {
    type: DiagnosticTypes.DUPLICATE,
    validate: (activity: any) =>
      activity.authoring.parts.filter(
        (ref: any) => activity.authoring.parts.filter((ref2: any) => ref2.id === ref.id).length > 1,
      ),
  },
  {
    type: DiagnosticTypes.PATTERN,
    validate: (activity: any) =>
      activity.authoring.parts.filter(
        (ref: any) => !ref.inherited && !/^[a-zA-Z0-9_\-: ]+$/.test(ref.id),
      ),
  },
  {
    type: DiagnosticTypes.BROKEN,
    validate: (activity: any, hierarchy: any, sequence: any[]) =>
      activity.authoring.rules.reduce((brokenColl: [], rule: any) => {
        const brokenActions = rule.event.params.actions.map((action: any) => {
          if (action.type === 'navigation') {
            if (action?.params?.target && action.params.target !== 'next') {
              if (!findInHierarchy(hierarchy, action.params.target)) {
                return {
                  ...rule,
                  owner: sequence.find((s) => s.resourceId === activity.id),
                  suggestedFix: `Screen does not exist, fix navigate to.`,
                };
              }
            }
          }
          return null;
        });
        return [...brokenColl, ...brokenActions.filter((e: any) => !!e)];
      }, []),
  },
];

export const validatePartIds = createAsyncThunk<any, any, any>(
  `${AppSlice}/validatePartIds`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();

    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);
    const hierarchy = getHierarchy(sequence);

    // console.log('validatePartIds', { allActivities });

    const errors: DiagnosticError[] = [];

    allActivities.forEach((activity) => {
      const foundProblems = validators.reduce(
        (probs: any, validator: any) => ({
          ...probs,
          [validator.type]: validator.validate(activity, hierarchy, sequence),
        }),
        {},
      );

      const countProblems = Object.keys(foundProblems).reduce(
        (c: number, current: any) => foundProblems[current].length + c,
        0,
      );

      if (countProblems > 0) {
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
        //console.log('blacklists: ', { lineageBlacklist, childrenBlackList });
        const testBlackList = Array.from(new Set([...lineageBlacklist, ...childrenBlackList]));

        const problems = Object.keys(foundProblems).reduce(
          (errs: any[], currentErr: any) => [
            ...errs,
            ...mapErrorProblems(foundProblems[currentErr], currentErr, sequence, testBlackList),
          ],
          [],
        );

        errors.push({
          activity: activitySequence,
          problems,
        });
      }
    });

    return fulfillWithValue({ errors });
  },
);
