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
import containsOperators from './operators/contains';
import equalityOperators from './operators/equality';
import mathOperators from './operators/math';
import rangeOperators from './operators/range';
import { evalScript, getAssignScript } from './scripting';

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
    rule.event.params = { ...rule.event.params, order: rule.priority, correct: !!rule.correct };
    applyToEveryCondition(rule.conditions, (condition: ConditionProperties) => {
      const ogValue = condition.value;
      let modifiedValue = ogValue;
      if (Array.isArray(ogValue)) {
        modifiedValue = ogValue.map((value) =>
          typeof value === 'string' ? evaluateValueExpression(value, env) : value,
        );
      }
      if (typeof ogValue === 'string') {
        modifiedValue = evaluateValueExpression(ogValue, env);
      }
      condition.value = modifiedValue;
    });
  });
};

export const check = async (
  state: Record<string, any>,
  rules: JanusRuleProperties[],
): Promise<Event[]> => {
  // setup script env context
  const assignScript = getAssignScript(state);
  // $log.info('assign: ', assignScript);
  const { env } = evalScript(assignScript);
  // TODO: check result for errors
  // $log.info('eval1', result);
  // evaluate all rule conditions against context
  const enabledRules = rules.filter((r) => !r.disabled);
  processRules(enabledRules, env);

  // finally run check
  const engine: Engine = rulesEngineFactory();
  const facts: Record<string, any> = env.toObj();

  enabledRules.forEach((rule) => {
    // $log.info('RULE: ', JSON.stringify(rule, null, 4));
    engine.addRule(rule);
  });

  const checkResult: EngineResult = await engine.run(facts);

  console.log('RE CHECK', { checkResult });
  let resultEvents: Event[] = [];
  const successEvents = checkResult.events.sort((a, b) => a.params?.order - b.params?.order);
  // if there are any correct in the success, get rid of the incorrect (defaultWrong most likely)
  if(successEvents.some(evt => evt.params?.correct === true)) {
    resultEvents = successEvents.filter(evt => evt.params?.correct === true);
  } else {
    // the failedEvents might be just because the invalid condition didn't trip
    // can't use these
    /* const failedEvents = checkResult.failureEvents
      .filter((evt) => evt.params?.correct === false)
      .sort((a, b) => a.params?.order - b.params?.order);
    console.log('INCORRECT RESULT', { failedEvents }); */
    // should only have "incorrect" at this point
    resultEvents = successEvents;
  }

  return resultEvents;
};
