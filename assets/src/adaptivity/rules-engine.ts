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

const processRules = (rules: RuleProperties[], env: Environment) => {
  rules.forEach((rule) => {
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
  rules: RuleProperties[],
): Promise<Event[]> => {
  // setup script env context
  const assignScript = getAssignScript(state);
  // $log.info('assign: ', assignScript);
  const { env } = evalScript(assignScript);
  // TODO: check result for errors
  // $log.info('eval1', result);
  // evaluate all rule conditions against context
  processRules(rules, env);

  // finally run check
  const engine: Engine = rulesEngineFactory();
  const facts: Record<string, any> = env.toObj();

  rules.forEach((rule) => {
    // $log.info('RULE: ', JSON.stringify(rule, null, 4));
    engine.addRule(rule);
  });

  const checkResult: EngineResult = await engine.run(facts);

  // for now just returning only success events
  return checkResult.events;
};
