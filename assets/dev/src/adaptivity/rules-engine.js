var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { Engine, } from 'json-rules-engine';
import { b64EncodeUnicode } from 'utils/decode';
import { CapiVariableTypes } from './capi';
import { janus_std } from './janus-scripts/builtin_functions';
import containsOperators from './operators/contains';
import equalityOperators from './operators/equality';
import mathOperators from './operators/math';
import rangeOperators from './operators/range';
import { bulkApplyState, evalAssignScript, evalScript, extractAllExpressionsFromText, getValue, looksLikeJson, } from './scripting';
const engineOperators = Object.assign(Object.assign(Object.assign(Object.assign({}, containsOperators), rangeOperators), equalityOperators), mathOperators);
const rulesEngineFactory = () => {
    const engine = new Engine([], { allowUndefinedFacts: true });
    Object.keys(engineOperators).forEach((opName) => {
        engine.addOperator(opName, engineOperators[opName]);
    });
    return engine;
};
const applyToEveryCondition = (top, callback) => {
    const conditions = top.all || top.any;
    conditions.forEach((condition) => {
        if (condition.all || condition.any) {
            // nested
            applyToEveryCondition(condition, callback);
        }
        else {
            callback(condition);
        }
    });
};
const evaluateValueExpression = (value, env) => {
    let result = value;
    const looksLikeJSON = looksLikeJson(value);
    // only if there is {} in it should it be processed, otherwise it's just a string
    if (value.indexOf('{') === -1 || looksLikeJSON) {
        return value;
    }
    // it might be that it's still just a string, if it's a JSON value (TODO, is this really something that would be authored?)
    // handle {{{q:1498672976730:866|stage.unknownabosrbance.Current Display Value}-{q:1522195641637:1014|stage.slide13_y_intercept.value}}/{q:1498673825305:874|stage.slide13_slope.value}}
    value = value.replace(/{{{/g, '(({').replace(/{{/g, '({').replace(/}}/g, '})');
    try {
        result = evalScript(value, env).result;
    }
    catch (e) {
        // TODO: this currently is good for when math is encountered
        // should create a "looksLikeMath" check above?? the math that is the problem
        // *might* always have a ^ in it... not sure...
        // otherwise any time it fails above for any reason, the value will be treated as a normal string
        console.warn(`[evaluateValueExpression] Error evaluating ${value} `, e);
    }
    return result;
};
const processRules = (rules, env) => {
    rules.forEach((rule, index) => {
        // tweak priority to match order
        rule.priority = index + 1;
        // note: maybe authoring / conversion should just write these here so we
        // dont have to do it at runtime
        rule.event.params = Object.assign(Object.assign({}, rule.event.params), { order: rule.priority, correct: !!rule.correct, default: !!rule.default });
        //need the 'type' property hence using JanusConditionProperties which extends ConditionProperties
        applyToEveryCondition(rule.conditions, (condition) => {
            const ogValue = condition.value;
            let modifiedValue = ogValue;
            if (Array.isArray(ogValue)) {
                modifiedValue = ogValue.map((value) => typeof value === 'string' ? evaluateValueExpression(value, env) : value);
            }
            if (typeof ogValue === 'string') {
                if (ogValue.indexOf('{') === -1) {
                    modifiedValue = ogValue;
                }
                else {
                    const evaluatedValue = evaluateValueExpression(ogValue, env);
                    if (typeof evaluatedValue === 'string') {
                        //if the converted value is string then we don't have to stringify (e.g. if the evaluatedValue = L and we stringyfy it then the value becomes '"L"' instead if 'L'
                        // hence a trap state checking 'L' === 'L' returns false as the expression becomes 'L' === '"L"')
                        modifiedValue = evaluatedValue;
                    }
                    else {
                        //Need to stringify only if it was converted into object during evaluation process and we expect it to be string
                        modifiedValue = JSON.stringify(evaluateValueExpression(ogValue, env));
                    }
                }
            }
            //if it type ===3 then it is a array. We need to wrap it in [] if it is not already wrapped.
            if (typeof ogValue === 'string' &&
                (condition === null || condition === void 0 ? void 0 : condition.type) === CapiVariableTypes.ARRAY &&
                ogValue.charAt(0) !== '[' &&
                ogValue.slice(-1) !== ']') {
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
export const findReferencedActivitiesInConditions = (conditions) => {
    const referencedActivities = new Set();
    conditions.forEach((condition) => {
        if (condition.fact && condition.fact.indexOf('|stage.') !== -1) {
            const referencedSequenceId = condition.fact.split('|stage.')[0];
            referencedActivities.add(referencedSequenceId);
        }
        if (typeof condition.value === 'string' && condition.value.indexOf('|stage.') !== -1) {
            // value could have more than one reference inside it
            const exprs = extractAllExpressionsFromText(condition.value);
            exprs.forEach((expr) => {
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
export const check = (state, rules, scoringContext, encodeResults = false) => __awaiter(void 0, void 0, void 0, function* () {
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
    const engine = rulesEngineFactory();
    const facts = env.toObj();
    enabledRules.forEach((rule) => {
        // $log.info('RULE: ', JSON.stringify(rule, null, 4));
        engine.addRule(rule);
    });
    const checkResult = yield engine.run(facts);
    /* console.log('RE CHECK', { checkResult }); */
    let resultEvents = [];
    const successEvents = checkResult.events.sort((a, b) => { var _a, _b; return ((_a = a.params) === null || _a === void 0 ? void 0 : _a.order) - ((_b = b.params) === null || _b === void 0 ? void 0 : _b.order); });
    // if every event is correct excluding the default wrong, then we are definitely correct
    let defaultWrong = successEvents.find((e) => { var _a, _b; return ((_a = e.params) === null || _a === void 0 ? void 0 : _a.default) && !((_b = e.params) === null || _b === void 0 ? void 0 : _b.correct); });
    if (!defaultWrong) {
        console.warn('no default wrong found, there should always be one!');
        // we should never actually get here, because the rules should be implanted earlier,
        // however, in case we still do, use this because it's better than nothing
        defaultWrong = defaultWrongRule.event;
    }
    resultEvents = successEvents.filter((evt) => evt !== defaultWrong);
    // if anything is correct, then we are correct
    const isCorrect = !!resultEvents.length && resultEvents.some((evt) => { var _a; return (_a = evt.params) === null || _a === void 0 ? void 0 : _a.correct; });
    // if we are not correct, then lets filter out any correct
    if (!isCorrect) {
        resultEvents = resultEvents.filter((evt) => { var _a; return !((_a = evt.params) === null || _a === void 0 ? void 0 : _a.correct); });
    }
    else {
        // if we are correct, then lets filter out any incorrect
        resultEvents = resultEvents.filter((evt) => { var _a; return (_a = evt.params) === null || _a === void 0 ? void 0 : _a.correct; });
    }
    // if we don't have any events left, then it's the default wrong
    if (!resultEvents.length) {
        resultEvents = [defaultWrong];
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
                const { actions } = evt.params;
                const mActions = actions.filter((action) => action.type === 'mutateState' &&
                    action.params.target === 'session.currentQuestionScore');
                return acc.concat(...acc, mActions);
            }, []);
            if (mutations.length) {
                const mutApplies = mutations.map(({ params }) => params);
                bulkApplyState(mutApplies, env);
                score = getValue('session.currentQuestionScore', env) || 0;
            }
        }
        else {
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
    }
    else {
        return finalResults;
    }
});
//# sourceMappingURL=rules-engine.js.map