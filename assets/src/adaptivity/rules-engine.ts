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
import { bulkApplyState, evalScript, getAssignScript, getValue } from './scripting';

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
      correctHasConditions:
        (rule.conditions as AllConditions).all?.length ||
        (rule.conditions as AnyConditions).any?.length ||
        0,
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

export interface CheckResult {
  correct: boolean;
  results: Event[];
  score: number;
  out_of: number;
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
  // setup script env context
  const assignScript = getAssignScript(state);
  // $log.info('assign: ', assignScript);
  evalScript(assignScript, env);
  // TODO: check result for errors
  // $log.info('eval1', result);
  // evaluate all rule conditions against context
  const enabledRules = rules.filter((r) => !r.disabled);
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

  // if there are any correct in the success, get rid of the incorrect (defaultWrong most likely)
  const isCorrect = successEvents.some((evt) => evt.params?.correct === true);
  //These are correct rules that do not have any condition so we need to make sure that the result does not have a wrong trap state otherwise it will
  // fire the correct one even though there is a wrong trap state - example ITTAC lesson
  const correctRulesWithoutConditions: any = successEvents.filter(
    (e) => e.params?.correct && e.params?.correctHasConditions > 0,
  );
  const wrongRulesWithoutDefaultWrong: any = successEvents.filter(
    (e) => !e.params?.default && !e.params?.correct,
  );
  const defaultCorrectRules: any = successEvents.filter(
    (e) => e.params?.correct && e.params?.default,
  );

  let filteredEvents = successEvents;

  if (
    correctRulesWithoutConditions?.length > 0 &&
    correctRulesWithoutConditions?.length !== successEvents?.length
  ) {
    filteredEvents = correctRulesWithoutConditions;
  } else if (wrongRulesWithoutDefaultWrong?.length > 0) {
    filteredEvents = wrongRulesWithoutDefaultWrong;
  } else if (defaultCorrectRules?.length > 0 && wrongRulesWithoutDefaultWrong?.length <= 0) {
    //if default correct rule is present and there is no wrong rule except the default
    //then return the defaultcorrect rule.
    filteredEvents = defaultCorrectRules;
  } else {
    filteredEvents = successEvents;
  }
  resultEvents = filteredEvents;

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
  };
  if (encodeResults) {
    return b64EncodeUnicode(JSON.stringify(finalResults));
  } else {
    return finalResults;
  }
};
