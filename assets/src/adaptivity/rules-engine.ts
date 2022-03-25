import { Environment } from 'janus-script';
import {
  AllConditions,
  AnyConditions,
  ConditionProperties,
  Engine,
  EngineResult,
  Event,
  NestedCondition,
  RuleProperties,
  TopLevelCondition,
} from 'json-rules-engine';
import { b64EncodeUnicode } from 'utils/decode';
import { CapiVariableTypes, JanusConditionProperties } from './capi';
import { janus_std } from './janus-scripts/builtin_functions';
import containsOperators from './operators/contains';
import equalityOperators from './operators/equality';
import mathOperators from './operators/math';
import rangeOperators from './operators/range';
import {
  bulkApplyState,
  evalAssignScript,
  evalScript,
  extractAllExpressionsFromText,
  getExpressionStringForValue,
  getValue,
  looksLikeJson,
} from './scripting';

export interface JanusRuleProperties extends RuleProperties {
  id?: string;
  disabled: boolean;
  default: boolean;
  correct: boolean;
  additionalScore?: number;
  forceProgress?: boolean;
}

const engineOperators: any = {
  ...containsOperators,
  ...rangeOperators,
  ...equalityOperators,
  ...mathOperators,
};

const rulesEngineFactory = () => {
  const engine = new Engine([], { allowUndefinedFacts: true });

  Object.keys(engineOperators).forEach((opName) => {
    engine.addOperator(opName, engineOperators[opName]);
  });

  return engine;
};

const applyToEveryCondition = (top: TopLevelCondition | NestedCondition, callback: any): void => {
  const conditions = (top as AllConditions).all || (top as AnyConditions).any;
  conditions.forEach((condition) => {
    if ((condition as AllConditions).all || (condition as AnyConditions).any) {
      // nested
      applyToEveryCondition(condition, callback);
    } else {
      callback(condition as ConditionProperties);
    }
  });
};

const evaluateValueExpression = (value: string, env: Environment) => {
  if (typeof value !== 'string') {
    return value;
  }
  const expr = getExpressionStringForValue({ type: CapiVariableTypes.STRING, value }, env);
  let { result } = evalScript(expr, env);
  if (result === value) {
    try {
      const evaluatedValue = evalScript(value, env);
      const canEval = evaluatedValue?.result !== undefined && !evaluatedValue.result.message;
      if (canEval) {
        result = evaluatedValue.result;
      }
    } catch (ex) {
      return result;
    }
  }
  return result;
};

const processRules = (rules: JanusRuleProperties[], env: Environment) => {
  rules.forEach((rule, index) => {
    // tweak priority to match order
    rule.priority = index + 1;
    // note: maybe authoring / conversion should just write these here so we
    // dont have to do it at runtime
    rule.event.params = {
      ...rule.event.params,
      order: rule.priority,
      correct: !!rule.correct,
      default: !!rule.default,
    };
    //need the 'type' property hence using JanusConditionProperties which extends ConditionProperties
    applyToEveryCondition(rule.conditions, (condition: JanusConditionProperties) => {
      const ogValue = condition.value;
      let modifiedValue = ogValue;
      if (Array.isArray(ogValue)) {
        modifiedValue = ogValue.map((value) =>
          typeof value === 'string' ? evaluateValueExpression(value, env) : value,
        );
      }
      if (
        condition?.operator === 'equalWithTolerance' ||
        condition?.operator === 'notEqualWithTolerance'
      ) {
        //Usually the tolerance is 5.28,2 where 5.28 is actual value and 2 is the tolerance so we need to separate the value and send it in evaluateValueExpression()
        //Also in case the tolerance is not specified and the value is 5.28 only, we need handle it so that it evaluates the actual value otherwise
        // it will evaluated as ""
        let actualValue = ogValue;
        let toleranceValue = 0;
        if (typeof ogValue === 'object') {
          if (ogValue.length === 2) {
            actualValue = ogValue[0];
            toleranceValue = ogValue[1];
          } else {
            actualValue = ogValue;
          }
        } else if (ogValue.lastIndexOf(',') !== -1) {
          toleranceValue = ogValue.substring(ogValue.lastIndexOf(',') + 1);
          actualValue = ogValue.substring(0, ogValue.lastIndexOf(','));
        } else {
          actualValue = ogValue;
        }
        const evaluatedValue = evaluateValueExpression(actualValue, env);
        modifiedValue = `${evaluatedValue},${toleranceValue}`;
      } else if (typeof ogValue === 'string' && ogValue.indexOf('{') === -1) {
        modifiedValue = ogValue;
      } else {
        const evaluatedValue = evaluateValueExpression(ogValue, env);
        if (typeof evaluatedValue === 'string') {
          //if the converted value is string then we don't have to stringify (e.g. if the evaluatedValue = L and we stringyfy it then the value becomes '"L"' instead if 'L'
          // hence a trap state checking 'L' === 'L' returns false as the expression becomes 'L' === '"L"')
          modifiedValue = evaluatedValue;
        } else if (typeof modifiedValue === 'number') {
          return modifiedValue;
        } else if (typeof ogValue === 'string') {
          //Need to stringify only if it was converted into object during evaluation process and we expect it to be string
          modifiedValue = JSON.stringify(evaluateValueExpression(ogValue, env));
        }
      }
      //if it type ===3 then it is a array. We need to wrap it in [] if it is not already wrapped.
      if (
        typeof ogValue === 'string' &&
        condition?.type === CapiVariableTypes.ARRAY &&
        ogValue.charAt(0) !== '[' &&
        ogValue.slice(-1) !== ']'
      ) {
        modifiedValue = `[${ogValue}]`;
      }
      condition.value = modifiedValue;
    });
  });
};

export const defaultWrongRule = {
  id: 'builtin.defaultWrong',
  name: 'defaultWrong',
  priority: 1,
  disabled: false,
  additionalScore: 0,
  forceProgress: false,
  default: true,
  correct: false,
  conditions: { all: [] },
  event: {
    type: 'builtin.defaultWrong',
    params: {
      actions: [
        {
          type: 'feedback',
          params: {
            feedback: {
              id: 'builtin.feedback',
              custom: {
                showCheckBtn: true,
                panelHeaderColor: 10027008,
                rules: [],
                facts: [],
                applyBtnFlag: false,
                checkButtonLabel: 'Next',
                applyBtnLabel: 'Show Solution',
                mainBtnLabel: 'Next',
                panelTitleColor: 16777215,
                lockCanvasSize: true,
                width: 350,
                palette: {
                  fillColor: 16777215,
                  fillAlpha: 1,
                  lineColor: 16777215,
                  lineAlpha: 1,
                  lineThickness: 0.1,
                  lineStyle: 0,
                  useHtmlProps: false,
                  backgroundColor: 'rgba(255,255,255,0)',
                  borderColor: 'rgba(255,255,255,0)',
                  borderWidth: '1px',
                  borderStyle: 'solid',
                },
                height: 100,
              },
              partsLayout: [
                {
                  id: 'builtin.feedback.textflow',
                  type: 'janus-text-flow',
                  custom: {
                    overrideWidth: true,
                    nodes: [
                      {
                        tag: 'p',
                        style: { fontSize: '16' },
                        children: [
                          {
                            tag: 'span',
                            style: { fontWeight: 'bold' },
                            children: [
                              {
                                tag: 'text',
                                text: 'Incorrect, please try again.',
                                children: [],
                              },
                            ],
                          },
                        ],
                      },
                    ],
                    x: 10,
                    width: 330,
                    overrideHeight: false,
                    y: 10,
                    z: 0,
                    palette: {
                      fillColor: 16777215,
                      fillAlpha: 1,
                      lineColor: 16777215,
                      lineAlpha: 0,
                      lineThickness: 0.1,
                      lineStyle: 0,
                      useHtmlProps: false,
                      backgroundColor: 'rgba(255,255,255,0)',
                      borderColor: 'rgba(255,255,255,0)',
                      borderWidth: '1px',
                      borderStyle: 'solid',
                    },
                    customCssClass: '',
                    height: 22,
                  },
                },
              ],
            },
          },
        },
      ],
    },
  },
};

export const findReferencedActivitiesInConditions = (conditions: any) => {
  const referencedActivities: Set<string> = new Set();

  conditions.forEach((condition: any) => {
    if (condition.fact && condition.fact.indexOf('|stage.') !== -1) {
      const referencedSequenceId = condition.fact.split('|stage.')[0];
      referencedActivities.add(referencedSequenceId);
    }
    if (typeof condition.value === 'string' && condition.value.indexOf('|stage.') !== -1) {
      // value could have more than one reference inside it
      const exprs = extractAllExpressionsFromText(condition.value);
      exprs.forEach((expr: string) => {
        if (expr.indexOf('|stage.') !== -1) {
          const referencedSequenceId = expr.split('|stage.')[0];
          referencedActivities.add(referencedSequenceId);
        }
      });
    }
    if (condition.any || condition.all) {
      const childRefs = findReferencedActivitiesInConditions(condition.any || condition.all);
      childRefs.forEach((ref) => referencedActivities.add(ref));
    }
  });

  return Array.from(referencedActivities);
};

export const getReferencedKeysInConditions = (conditions: any) => {
  const references: Set<string> = new Set();

  conditions.forEach((condition: any) => {
    // the fact *must* be a reference to a key we need
    if (condition.fact) {
      references.add(condition.fact);
    }
    // the value *might* contain a reference to a key we need
    if (
      typeof condition.value === 'string' &&
      condition.value.search(/app\.|variables\.|stage\.|session\./) !== -1
    ) {
      // value could have more than one reference inside it
      const exprs = extractAllExpressionsFromText(condition.value);
      const expressions = condition.value.match(/{([^{^}]+)}/g);
      exprs.forEach((expr: string) => {
        if (expr.search(/app\.|variables\.|stage\.|session\./) !== -1) {
          references.add(expr);
        }
      });
      expressions.forEach((expr: string) => {
        if (expr.search(/app\.|variables\.|stage\.|session\./) !== -1) {
          //we should remove the {}
          const actualExp = expr.substring(1, expr.length - 1);
          if (!references.has(actualExp)) {
            references.add(expr.substring(1, expr.length - 1));
          }
        }
      });
    }
    if (condition.any || condition.all) {
      const childRefs = findReferencedActivitiesInConditions(condition.any || condition.all);
      childRefs.forEach((ref) => references.add(ref));
    }
  });

  return Array.from(references);
};

export interface CheckResult {
  correct: boolean;
  results: Event[];
  score: number;
  out_of: number;
  debug?: any;
}

export interface ScoringContext {
  maxScore: number;
  maxAttempt: number;
  trapStateScoreScheme: boolean;
  negativeScoreAllowed: boolean;
  currentAttemptNumber: number;
}

export const check = async (
  state: Record<string, unknown>,
  rules: JanusRuleProperties[],
  scoringContext: ScoringContext,
  encodeResults = false,
): Promise<CheckResult | string> => {
  // load the std lib
  const { env } = evalScript(janus_std);

  const { result: assignResults } = evalAssignScript(state, env);
  // console.log('RULES ENGINE STATE ASSIGN', { assignResults, state, env });

  // evaluate all rule conditions against context
  const enabledRules = rules.filter((r) => !r.disabled);
  if (enabledRules.length === 0 || !enabledRules.find((r) => r.default && !r.correct)) {
    enabledRules.push(defaultWrongRule);
  }
  processRules(enabledRules, env);

  // finally run check
  const engine: Engine = rulesEngineFactory();
  const facts: Record<string, unknown> = env.toObj();

  enabledRules.forEach((rule) => {
    // $log.info('RULE: ', JSON.stringify(rule, null, 4));
    engine.addRule(rule);
  });

  const checkResult: EngineResult = await engine.run(facts);

  /* console.log('RE CHECK', { checkResult }); */
  let resultEvents: Event[] = [];
  const successEvents = checkResult.events.sort((a, b) => a.params?.order - b.params?.order);

  // if every event is correct excluding the default wrong, then we are definitely correct
  let defaultWrong = successEvents.find((e) => e.params?.default && !e.params?.correct);
  if (!defaultWrong) {
    console.warn('no default wrong found, there should always be one!');
    // we should never actually get here, because the rules should be implanted earlier,
    // however, in case we still do, use this because it's better than nothing
    defaultWrong = defaultWrongRule.event;
  }
  resultEvents = successEvents.filter((evt) => evt !== defaultWrong);
  // if anything is correct, then we are correct
  const isCorrect = !!resultEvents.length && resultEvents.some((evt) => evt.params?.correct);
  // if we are not correct, then lets filter out any correct
  if (!isCorrect) {
    resultEvents = resultEvents.filter((evt) => !evt.params?.correct);
  } else {
    // if we are correct, then lets filter out any incorrect
    resultEvents = resultEvents.filter((evt) => evt.params?.correct);
  }

  // if we don't have any events left, then it's the default wrong
  if (!resultEvents.length) {
    resultEvents = [defaultWrong as Event];
  }

  let score = 0;
  //below condition make sure the score calculation will happen only if the answer is correct and
  //in case of incorrect answer if negative scoring is allowed then calculation will proceed.
  if (isCorrect || scoringContext.negativeScoreAllowed) {
    if (scoringContext.trapStateScoreScheme) {
      // apply all the actions from the resultEvents that mutate the state
      // then check the session.currentQuestionScore and clamp it against the maxScore
      // setting that value to score
      const mutations = resultEvents.reduce((acc, evt) => {
        const { actions } = evt.params as Record<string, any>;
        const mActions = actions.filter(
          (action: any) =>
            action.type === 'mutateState' &&
            action.params.target === 'session.currentQuestionScore',
        );
        return acc.concat(...acc, mActions);
      }, []);
      if (mutations.length) {
        const mutApplies = mutations.map(({ params }) => params);
        bulkApplyState(mutApplies, env);
        score = getValue('session.currentQuestionScore', env) || 0;
      }
    } else {
      const { maxScore, maxAttempt, currentAttemptNumber } = scoringContext;
      const scorePerAttempt = maxScore / maxAttempt;
      score = maxScore - scorePerAttempt * (currentAttemptNumber - 1);
    }
    score = Math.min(score, scoringContext.maxScore);
    if (!scoringContext.negativeScoreAllowed) {
      score = Math.max(0, score);
    }
  }

  const finalResults = {
    correct: isCorrect,
    score,
    out_of: scoringContext.maxScore || 0,
    results: resultEvents,
    debug: {
      sent: resultEvents.map((e) => e.type),
      all: successEvents.map((e) => e.type),
    },
  };
  if (encodeResults) {
    return b64EncodeUnicode(JSON.stringify(finalResults));
  } else {
    return finalResults;
  }
};
