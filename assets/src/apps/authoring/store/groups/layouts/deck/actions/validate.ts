import { createAsyncThunk } from '@reduxjs/toolkit';
import { JanusConditionProperties } from 'adaptivity/capi';
import { janus_std } from 'adaptivity/janus-scripts/builtin_functions';
import {
  checkExpressionsWithWrongBrackets,
  defaultGlobalEnv,
  evalScript,
} from 'adaptivity/scripting';
import { forEachCondition } from 'apps/authoring/components/AdaptivityEditor/ConditionsBlockEditor';
import { LessonVariable } from 'apps/authoring/components/AdaptivityEditor/VariablePicker';
import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';
import { AppSlice } from 'apps/authoring/store/app/name';
import { IActivity, selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
  SequenceEntry,
  SequenceEntryType,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { Part } from 'components/activities';
import { Environment } from 'janus-script';
import has from 'lodash/has';
import uniqBy from 'lodash/uniqBy';
import { clone } from 'utils/common';
import { selectState as selectPageState } from '../../../../page/slice';

export interface DiagnosticProblem {
  owner: SequenceEntry<SequenceEntryType>; // note DiagnosticsWindow *requires* this
  type: DiagnosticTypes;
  // getSuggestion: () => any;
  // getSolution: (resolution: unknown) => () => void;
  suggestedFix: string;
  item: any;
}
export interface DiagnosticError {
  activity: unknown;
  problems: DiagnosticProblem[];
}

export interface Validator {
  type: DiagnosticTypes;
  validate: (
    activity: IActivity,
    sequence?: SequenceEntry<SequenceEntryType>[],
    parts?: any[],
    allActivities?: any[],
  ) => DiagnosticProblem[];
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

const parseTarget = (target: string) => {
  let screen: string | undefined;
  if (target.indexOf('|') > -1) {
    const screenSplit = target.split('|');
    screen = screenSplit[0].replace('{', '');
    screen = screen.replace('(', '');
  }

  const targetNameIdx = target.search(/app|variables|stage|session/);
  const split = target.slice(targetNameIdx).split('.');
  const type = split[0] as string;
  const id = split[1] as string;

  return {
    type,
    id,
    screen,
  };
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
  const isExpression = target.match(/{([^{^}]+)}/g);
  if (isExpression) {
    return false;
  }

  const { id, type } = parseTarget(target);
  if (!id) {
    return false;
  }
  switch (type) {
    case 'app':
      return id === 'active' || parts.some((p: any) => p.id === id);
    case 'variables':
    case 'stage':
      return parts.some((p: any) => p.id === id);
    case 'session':
      return !!id;
    default:
      return false;
  }
};

const validateValueExpression = (condition: JanusConditionProperties, rule: any, owner: any) => {
  if (typeof condition.value === 'string') {
    const evaluatedExp = checkExpressionsWithWrongBrackets(condition.value);
    if (evaluatedExp !== condition.value) {
      return {
        condition,
        rule,
        fact: rule,
        owner,
        suggestedFix: evaluatedExp,
      };
    }
  }
};

const validateValue = (condition: JanusConditionProperties, rule: any, owner: any) => {
  return has(condition, 'value') && (condition.value === null || condition.value === undefined)
    ? {
        condition,
        rule,
        owner,
        suggestedFix: ``,
      }
    : null;
};

const validateOwner = (value: string, activityList: any[], sequence: any[]) => {
  const { id, screen } = parseTarget(value);
  if (screen) {
    const act = getOwnerByScreenId(screen, activityList || [], sequence);
    const isValidPart = act?.content.partsLayout.find((part: Part) => part.id === id);

    if (!isValidPart) {
      return {
        suggestedFix: value,
      };
    }
  }
  return null;
};

const getOwnerByScreenId = (screen: string, activityList: any[], sequence: any[]) => {
  return activityList?.find((activity) => {
    const seqItem = sequence.find((s) => s.resourceId === activity.id);
    return seqItem?.custom.sequenceId === screen;
  });
};

const getExpressionTarget = (value: any) => {
  let val = Array.isArray(value) ? value[0].toString() : value.toString();
  const expr = val.match(/{([^{^}]+)}/g);
  if (expr && expr.length > 0) {
    val = expr[0];
  }

  return val;
};

export const validators: Validator[] = [
  {
    type: DiagnosticTypes.INVALID_EXPRESSION,
    validate: (activity, sequence) => {
      if (!sequence) {
        throw new Error('INVALID_EXPRESSION VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error(
          'INVALID_EXPRESSION VALIDATION: activity.content.partsLayout is undefined!',
        );
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      const parts = activity.content.partsLayout;
      const brokenExpressions: any[] = [];
      parts.forEach((part: any) => {
        const Klass = customElements.get(part.type);
        if (Klass) {
          const instance = new Klass() as any;
          if (instance.getCapabilities) {
            const capabilities = instance.getCapabilities();
            if (capabilities.canUseExpression) {
              if (instance.validateUserConfig) {
                const partClone: any = clone(part);
                const formattedExpression = instance.validateUserConfig(partClone, owner);
                if (formattedExpression?.length) {
                  brokenExpressions.push(...formattedExpression);
                }
              }
            }
          }
        }
      });

      return [...brokenExpressions];
    },
  },
  {
    type: DiagnosticTypes.DUPLICATE,
    validate: (activity, sequence, allParts, allActivities) => {
      if (!sequence) {
        throw new Error('DUPLICATE VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error('DUPLICATE VALIDATION: activity.content.partsLayout is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      if (!owner) {
        throw new Error(`DUPLICATE VALIDATION: activity ${activity.id} not found in sequence!`);
      }
      const lineage = getSequenceLineage(sequence, owner.custom.sequenceId);
      // remove self from lineage
      lineage.pop();
      // need to make sure there are no duplicates in the lineage
      const lineageBlacklist = lineage
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        .map((s) => allActivities!.find((a) => a.id === s.resourceId))
        .map((a) => (a?.content?.partsLayout || []).map((ref: any) => ref.id))
        .reduce((acc, cur) => acc.concat(cur), []);
      const partList = activity.content.partsLayout;
      const selfDupes = partList
        .filter((ref: any) => partList.filter((ref2: any) => ref2.id === ref.id).length > 1)
        .map((ref: any) => ({ ...ref, owner }));
      const lineageDupes = partList
        .filter((ref: any) => lineageBlacklist.includes(ref.id))
        .map((ref: any) => ({ ...ref, owner }));
      const dupes = [...selfDupes, ...lineageDupes];
      return dupes;
    },
  },
  {
    type: DiagnosticTypes.PATTERN,
    validate: (activity, sequence) => {
      if (!sequence) {
        throw new Error('PATTERN VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error('PATTERN VALIDATION: activity.content.partsLayout is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      const partList = activity.content.partsLayout;
      return partList
        .filter((ref: any) => !ref.inherited && !/^[a-zA-Z0-9_\-: ]+$/.test(ref.id))
        .map((ref: any) => ({ ...ref, owner }));
    },
  },
  {
    type: DiagnosticTypes.BROKEN,
    validate: (activity, sequence) => {
      if (!sequence) {
        throw new Error('BROKEN NAVIGATION VALIDATION: sequence is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      const hierarchy = getHierarchy(sequence);
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
    validate: (activity, sequence, parts) => {
      if (!sequence) {
        throw new Error('INVALID_TARGET_MUTATE VALIDATION: sequence is undefined!');
      }
      if (!parts) {
        throw new Error('INVALID_TARGET_MUTATE VALIDATION: parts is undefined!');
      }
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
    validate: (activity, sequence, parts) => {
      if (!sequence) {
        throw new Error('INVALID_TARGET_INIT VALIDATION: sequence is undefined!');
      }
      if (!parts) {
        throw new Error('INVALID_TARGET_INIT VALIDATION: parts is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      const initStateFacts = activity.content?.custom?.facts;
      return initStateFacts.reduce(
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
    validate: (activity, sequence, parts) => {
      if (!sequence) {
        throw new Error('INVALID_TARGET_COND VALIDATION: sequence is undefined!');
      }
      if (!parts) {
        throw new Error('INVALID_TARGET_COND VALIDATION: parts is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        const brokenConditionValues: any[] = [];
        forEachCondition(conditions, (condition: JanusConditionProperties) => {
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
    validate: (activity, sequence) => {
      if (!sequence) {
        throw new Error('INVALID_VALUE VALIDATION: sequence is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      return activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        const brokenConditionValues: any[] = [];
        forEachCondition(conditions, (condition: JanusConditionProperties) => {
          brokenConditionValues.push(validateValue(condition, rule, owner));
        });

        return [...broken, ...brokenConditionValues];
      }, []);
    },
  },
  {
    type: DiagnosticTypes.INVALID_EXPRESSION_VALUE,
    validate: (activity, sequence) => {
      if (!sequence) {
        throw new Error('INVALID_EXPRESSION_VALUE VALIDATION: sequence is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);
      const initStateFacts = activity.content?.custom?.facts;
      const brokenFactConditionValues: any[] = [];
      const brokenFacts = initStateFacts.reduce((broken: any[], fact: any) => {
        const updatedFact = validateValueExpression(fact, fact, owner);
        if (updatedFact) {
          return updatedFact && broken ? [...broken, updatedFact] : [updatedFact];
        }
      }, []);
      if (brokenFacts?.length) {
        const updatedFacts = brokenFacts?.filter((fact: any) => fact);
        if (updatedFacts) {
          brokenFactConditionValues.push(...updatedFacts);
        }
      }
      const brokenConditionValues = activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        const brokenConditionValues: any[] = [];
        forEachCondition(conditions, (condition: JanusConditionProperties) => {
          brokenConditionValues.push(validateValueExpression(condition, rule, owner));
        });

        return [...broken, ...brokenConditionValues];
      }, []);

      return [...brokenConditionValues, ...brokenFactConditionValues];
    },
  },
  {
    type: DiagnosticTypes.INVALID_OWNER_INIT,
    validate: (activity, sequence, parts, activityList) => {
      if (!sequence) {
        throw new Error('DUPLICATE VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error('DUPLICATE VALIDATION: activity.content.partsLayout is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);

      /* Init State Facts */

      const initStateFacts = activity.content?.custom?.facts;
      const brokenFactConditionValues: any[] = [];
      const brokenFacts = initStateFacts.reduce((broken: any[], fact: any) => {
        const val = getExpressionTarget(fact.value);
        const fix = validateOwner(val, activityList || [], sequence);
        if (fix) {
          const error = {
            fact,
            owner,
            ...fix,
          };
          broken = [...broken, error];
        }
        return broken;
      }, []);

      if (brokenFacts?.length) {
        const updatedFacts = brokenFacts?.filter((fact: any) => fact);
        if (updatedFacts) {
          brokenFactConditionValues.push(...updatedFacts);
        }
      }

      return [...brokenFactConditionValues];
    },
  },
  {
    type: DiagnosticTypes.INVALID_OWNER_CONDITION,
    validate: (activity, sequence, parts, activityList) => {
      if (!sequence) {
        throw new Error('DUPLICATE VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error('DUPLICATE VALIDATION: activity.content.partsLayout is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);

      /* Conditions */

      const brokenConditionValues = activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const conditions = [...(rule.conditions.all || []), ...(rule.conditions.any || [])];

        forEachCondition(conditions, (condition: JanusConditionProperties) => {
          const val = getExpressionTarget(condition.value);

          if (typeof val === 'string') {
            const fix = validateOwner(val, activityList || [], sequence);
            if (fix) {
              const error = {
                condition,
                owner,
                rule,
                ...fix,
              };
              broken = [...broken, error];
            }
          } else if (Array.isArray(val)) {
            val.forEach((v) => {
              if (typeof v === 'string') {
                const fix = validateOwner(v, activityList || [], sequence);
                if (fix) {
                  broken = [
                    ...broken,
                    {
                      condition,
                      rule,
                      owner,
                      ...fix,
                    },
                  ];
                }
              }
            });
          }
        });

        return broken;
      }, []);

      return [...brokenConditionValues];
    },
  },
  {
    type: DiagnosticTypes.INVALID_OWNER_MUTATE,
    validate: (activity, sequence, parts, activityList) => {
      if (!sequence) {
        throw new Error('DUPLICATE VALIDATION: sequence is undefined!');
      }
      if (!activity.content?.partsLayout) {
        throw new Error('DUPLICATE VALIDATION: activity.content.partsLayout is undefined!');
      }
      const owner = sequence.find((s) => s.resourceId === activity.id);

      /* Mutate Actions */

      const brokenMutateValues = activity.authoring.rules.reduce((broken: any[], rule: any) => {
        const brokenActions = rule.event.params.actions.map((action: any) => {
          if (action.type === 'mutateState') {
            const val = getExpressionTarget(action.params.value);

            if (typeof val === 'string') {
              const fix = validateOwner(val, activityList || [], sequence);
              if (fix) {
                const error = {
                  action,
                  owner,
                  ...rule,
                  ...fix,
                };
                broken = [...broken, error];
              }
            } else if (Array.isArray(val)) {
              val.forEach((v) => {
                if (typeof v === 'string') {
                  const fix = validateOwner(v, activityList || [], sequence);
                  if (fix) {
                    broken = [
                      ...broken,
                      {
                        action,
                        rule,
                        owner,
                        ...fix,
                      },
                    ];
                  }
                }
              });
            }
          }
          return null;
        });
        return [...broken, ...brokenActions];
      }, []);

      return [...brokenMutateValues];
    },
  },
];

export const diagnosePage = (page: any, allActivities: any[], sequence: any[]) => {
  const hierarchy = getHierarchy(sequence);
  //console.log('diagnosePage', { page, allActivities, hierarchy, sequence });
  const errors: DiagnosticError[] = [];

  const partsList = allActivities.reduce(
    (list: any[], act: any) => list.concat(act.content.partsLayout),
    [],
  );

  const parts = uniqBy(
    [
      ...partsList,
      ...(page?.custom?.everApps || []),
      ...(page?.custom?.variables || []).map((v: LessonVariable) => ({ id: v.name })),
    ],
    (i: any) => i.id,
  );

  allActivities.forEach((activity: any) => {
    const foundProblems = validators.reduce(
      (probs: any, validator: any) => ({
        ...probs,
        [validator.type]: validator
          .validate(activity, sequence, parts, allActivities)
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
      const testBlackList = Array.from(new Set([...lineageBlacklist, ...childrenBlackList]));

      const problems = Object.keys(foundProblems).reduce(
        (errs: any[], currentErr: any) => [
          ...errs,
          ...mapErrorProblems(foundProblems[currentErr], currentErr, sequence, testBlackList),
        ],
        [],
      );

      console.log('blacklists: ', { lineageBlacklist, childrenBlackList, foundProblems, problems });

      errors.push({
        activity: activitySequence,
        problems,
      });
    }
  });

  return errors;
};

const validateLessonVariables = (page: any) => {
  if (!page?.custom?.variables) {
    return [];
  }

  const allNames = page.custom.variables.map((v: any) => v.name);
  // variables can and will ref previous ones
  // they will reference them "globally" so need to track the above
  // in order to prepend the "variables" namespace
  const statements: string[] = page.custom.variables
    .map((v: any) => {
      if (!v.name || !v.expression) {
        return '';
      }
      let expr = v.expression;
      allNames.forEach((name: string) => {
        const regex = new RegExp(`{${name}}`, 'g');
        expr = expr.replace(regex, `{variables.${name}}`);
      });

      const stmt = { expression: `let {variables.${v.name.trim()}} = ${expr};`, name: v.name };
      return stmt;
    })
    .filter((s: any) => s);
  const testEnv = new Environment();
  evalScript(janus_std, testEnv);
  if (page.customScript) {
    try {
      evalScript(page.customScript, testEnv);
    } catch (e) {
      console.error('Error evaluating custom script: ', e);
    }
  }
  // execute each sequentially in case there are errors (missing functions)
  const broken: any[] = [];
  statements.forEach((statement: any) => {
    try {
      const result = evalScript(statement.expression, testEnv);
      if (result.result !== null) {
        broken.push({
          owner: page,
          id: statement.name,
          item: statement,
          suggestedFix: ``,
        });
      }
    } catch (e) {
      broken.push({
        owner: page,
        key: statement.name,
        fact: statement,
        suggestedFix: ``,
      });
    }
  });
  return [...broken];
};

export const validatePartIds = createAsyncThunk<any, any, any>(
  `${AppSlice}/validatePartIds`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();

    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);
    const currentLesson = selectPageState(rootState as any);

    // console.log('validatePartIds', { allActivities });

    const errors = diagnosePage(currentLesson, allActivities, sequence);

    return fulfillWithValue({ errors });
  },
);

export const validateVariables = createAsyncThunk<any, any, any>(
  `${AppSlice}/validateVariables`,
  async (payload, { getState, fulfillWithValue }) => {
    const rootState = getState();
    const currentLesson = selectPageState(rootState as any);
    const errors = validateLessonVariables(currentLesson);
    return fulfillWithValue({ errors });
  },
);
