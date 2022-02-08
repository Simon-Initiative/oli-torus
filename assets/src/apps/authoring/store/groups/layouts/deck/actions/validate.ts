import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice } from 'apps/authoring/store/app/name';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';
import { forEachCondition } from 'apps/authoring/components/AdaptivityEditor/ConditionsBlockEditor';
import { selectState as selectPageState } from '../../../../page/slice';
import has from 'lodash/has';
import uniqBy from 'lodash/uniqBy';
import { LessonVariable } from 'apps/authoring/components/AdaptivityEditor/VariablePicker';

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
      suggestedFix:
        typeof item.suggestedFix === 'string'
          ? item.suggestedFix
          : generateSuggestion(item.id, blackList),
    };
  });

const validateTarget = (target: string, activity: any, parts: any[]) => {
  const targetNameIdx = target.search(/app|variables|stage|session/);
  const split = target.slice(targetNameIdx).split('.');
  const type = split[0] as string;
  const targetId = split[1] as string;
  if (!targetId) {
    return false;
  }
  switch (type) {
    case 'app':
      return targetId === 'active' || parts.some((p: any) => p.id === targetId);
    case 'variables':
    case 'stage':
      return parts.some((p: any) => p.id === targetId);
    case 'session':
      return !!targetId;
    default:
      return false;
  }
};

const validateValue = (condition: any, rule: any, owner: any) => {
  return has(condition, 'value') && (condition.value === null || condition.value === undefined)
    ? {
        condition,
        rule,
        owner,
        suggestedFix: ``,
      }
    : null;
};

export const validators = [
  {
    type: DiagnosticTypes.DUPLICATE,
    validate: (activity: any) =>
      activity.content.partsLayout.filter(
        (ref: any) =>
          activity.content.partsLayout.filter((ref2: any) => ref2.id === ref.id).length > 1,
      ),
  },
  {
    type: DiagnosticTypes.PATTERN,
    validate: (activity: any) =>
      activity.content.partsLayout.filter(
        (ref: any) => !ref.inherited && !/^[a-zA-Z0-9_\-: ]+$/.test(ref.id),
      ),
  },
  {
    type: DiagnosticTypes.BROKEN,
    validate: (activity: any, hierarchy: any, sequence: any[]) => {
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((brokenColl: [], rule: any) => {
        const brokenActions = rule.event.params.actions.map((action: any) => {
          if (action.type === 'navigation') {
            if (action?.params?.target && action.params.target !== 'next') {
              if (!findInHierarchy(hierarchy, action.params.target)) {
                return {
                  ...rule,
                  owner,
                  suggestedFix: `Screen does not exist, fix navigate to.`,
                };
              }
            }
          }
          return null;
        });
        return [...brokenColl, ...brokenActions];
      }, []);
    },
  },
  {
    type: DiagnosticTypes.INVALID_TARGET_MUTATE,
    validate: (activity: any, hierarchy: any, sequence: any[], parts: any[]) => {
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((brokenColl: [], rule: any) => {
        const brokenActions = rule.event.params.actions.map((action: any) => {
          if (action.type === 'mutateState') {
            return validateTarget(action.params.target, activity, parts)
              ? null
              : {
                  ...rule,
                  action,
                  owner,
                  suggestedFix: ``,
                };
          }
          return null;
        });
        return [...brokenColl, ...brokenActions];
      }, []);
    },
  },
  {
    type: DiagnosticTypes.INVALID_TARGET_INIT,
    validate: (activity: any, hierarchy: any, sequence: any[], parts: any[]) => {
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.content.custom.facts.reduce(
        (broken: any[], fact: any) => [
          ...broken,
          validateTarget(fact.target, activity, parts)
            ? null
            : {
                fact,
                owner,
                suggestedFix: ``,
              },
        ],
        [],
      );
    },
  },
  {
    type: DiagnosticTypes.INVALID_TARGET_COND,
    validate: (activity: any, hierarchy: any, sequence: any[], parts: any[]) => {
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        const brokenConditionValues: any[] = [];
        forEachCondition(conditions, (condition: any) => {
          if (!validateTarget(condition.fact, activity, parts)) {
            brokenConditionValues.push({
              condition,
              rule,
              owner,
              suggestedFix: ``,
            });
          }
        });

        return [...broken, ...brokenConditionValues];
      }, []);
    },
  },
  {
    type: DiagnosticTypes.INVALID_VALUE,
    validate: (activity: any, hierarchy: any, sequence: any[]) => {
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        const brokenConditionValues: any[] = [];
        forEachCondition(conditions, (condition: any) => {
          brokenConditionValues.push(validateValue(condition, rule, owner));
        });

        return [...broken, ...brokenConditionValues];
      }, []);
    },
  },
];

export const validatePartIds = createAsyncThunk<any, any, any>(
  `${AppSlice}/validatePartIds`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();

    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);
    const hierarchy = getHierarchy(sequence);
    const currentLesson = selectPageState(rootState as any);

    // console.log('validatePartIds', { allActivities });

    const errors: DiagnosticError[] = [];

    const partsList = allActivities.reduce(
      (list: any[], act: any) => list.concat(act.content.partsLayout),
      [],
    );

    const parts = uniqBy(
      [
        ...partsList,
        ...(currentLesson?.custom?.everApps || []),
        ...(currentLesson?.custom?.variables || []).map((v: LessonVariable) => ({ id: v.name })),
      ],
      (i: any) => i.id,
    );

    allActivities.forEach((activity: any) => {
      const foundProblems = validators.reduce(
        (probs: any, validator: any) => ({
          ...probs,
          [validator.type]: validator
            .validate(activity, hierarchy, sequence, parts)
            .filter((e: any) => !!e),
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
          .map((a) => (a?.content?.partsLayout || []).map((ref: any) => ref.id))
          .reduce((acc, cur) => acc.concat(cur), []);
        const hierarchyItem = findInHierarchy(hierarchy, activitySequence.custom.sequenceId);
        const childrenBlackList: string[] = flattenHierarchy(hierarchyItem?.children ?? [])
          .map((s) => allActivities.find((a) => a.id === s.resourceId))
          .map((a) => (a?.content?.partsLayout || []).map((ref: any) => ref.id))
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
