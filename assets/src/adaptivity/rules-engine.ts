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
import { janus_std } from './janus-scripts/builtin_functions';
import containsOperators from './operators/contains';
import equalityOperators from './operators/equality';
import mathOperators from './operators/math';
import rangeOperators from './operators/range';
import { bulkApplyState, evalAssignScript, evalScript, getValue } from './scripting';

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
  // only if there is {} in it should it be processed, otherwise it's just a string
  if (value.indexOf('{') === -1) {
    return value;
  }
  // it might be that it's still just a string, if it's a JSON value (TODO, is this really something that would be authored?)
  // handle {{{q:1498672976730:866|stage.unknownabosrbance.Current Display Value}-{q:1522195641637:1014|stage.slide13_y_intercept.value}}/{q:1498673825305:874|stage.slide13_slope.value}}
  value = value.replace(/{{{/g, '(({').replace(/{{/g, '({').replace(/}}/g, '})');
  return evalScript(value, env).result;
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
    applyToEveryCondition(rule.conditions, (condition: ConditionProperties) => {
      const ogValue = condition.value;
      let modifiedValue = ogValue;
      if (Array.isArray(ogValue)) {
        modifiedValue = ogValue.map((value) =>
          typeof value === 'string' ? evaluateValueExpression(value, env) : value,
        );
      }
      if (typeof ogValue === 'string') {
        if (ogValue.indexOf('{') === -1) {
          modifiedValue = ogValue;
        } else {
          //Need to stringify only if it was converted into object during evaluation process and we expect it to be string
          modifiedValue = JSON.stringify(evaluateValueExpression(ogValue, env));
        }
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
  console.log('RULES ENGINE CHECK', { assignResults, state, env });

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
  if (scoringContext.trapStateScoreScheme) {
    // apply all the actions from the resultEvents that mutate the state
    // then check the session.currentQuestionScore and clamp it against the maxScore
    // setting that value to score
    const mutations = resultEvents.reduce((acc, evt) => {
      const { actions } = evt.params as Record<string, any>;
      const mActions = actions.filter(
        (action: any) =>
          action.type === 'mutateState' && action.params.target === 'session.currentQuestionScore',
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
