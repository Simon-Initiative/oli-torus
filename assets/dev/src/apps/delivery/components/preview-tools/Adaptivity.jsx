var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React, { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import { setLastCheckResults } from '../../store/features/adaptivity/slice';
// Adaptivity Placeholder
const Adaptivity = ({ currentActivity }) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const [expandedRules, setExpandedRules] = useState({});
    const dispatch = useDispatch();
    const triggerAction = (e, rule) => __awaiter(void 0, void 0, void 0, function* () {
        var _h, _j;
        e.preventDefault();
        // Strip out any rules that are not the selected rule
        const customRules = (_j = (_h = currentActivity.authoring) === null || _h === void 0 ? void 0 : _h.rules) === null || _j === void 0 ? void 0 : _j.filter((activityRule) => activityRule.id === rule.id);
        // Construct custom check results to fire after triggering the check event
        const customCheckResults = [
            {
                params: {
                    actions: [...rule.event.params.actions],
                    correct: !!rule.correct,
                    default: !!rule.default,
                    order: rule.priority,
                },
                type: rule.event.type,
            },
        ];
        // Send in the custom rules for processing
        dispatch(triggerCheck({ activityId: currentActivity.id, customRules }));
        // Fire off our custom check results
        yield dispatch(setLastCheckResults({ results: customCheckResults }));
    });
    useEffect(() => {
        setExpandedRules({});
    }, [currentActivity]);
    // helper because of lint
    const hasOwnProperty = (obj, property) => Object.prototype.hasOwnProperty.call(obj || {}, property);
    return (<div className="adaptivity">
      <div className="accordion">
        {/* InitState */}
        {((_c = (_b = (_a = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.content) === null || _a === void 0 ? void 0 : _a.custom) === null || _b === void 0 ? void 0 : _b.facts) === null || _c === void 0 ? void 0 : _c.length) > 0 && (<div key={`init-${currentActivity.id}`} className="card initState">
            <div className="card-header p-2" id={`initHeading-${currentActivity.id}`}>
              <h2 className="mb-0">
                <button className="btn btn-link btn-block text-left" type="button" data-toggle="collapse" data-target={`#collapse`} aria-expanded={expandedRules[`initState-${currentActivity.id}`]} aria-controls={`collapse`} onClick={(e) => setExpandedRules(Object.assign(Object.assign({}, expandedRules), { [`initState-${currentActivity.id}`]: !expandedRules[`initState-${currentActivity.id}`] }))}>
                  <span className={`chevron-arrow mr-2${expandedRules[`initState-${currentActivity.id}`] ? ' rotate' : ''}`}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                      <path fillRule="evenodd" d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"/>
                    </svg>
                  </span>
                  Initial State
                </button>
              </h2>
            </div>
            <div id={`collapse`} className="collapse" aria-labelledby={`initHeading-${currentActivity.id}`}>
              <div className="mt-2 pt-2 px-3 font-weight-bold text-uppercase">Facts</div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {(_e = (_d = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.content) === null || _d === void 0 ? void 0 : _d.custom) === null || _e === void 0 ? void 0 : _e.facts.map((fact, factIndex) => (<li key={factIndex} className="list-group-item">{`${fact.target} ${fact.operator} ${JSON.stringify(fact.value)}`}</li>))}
                </ul>
              </div>
            </div>
          </div>)}
        {/* Rules */}
        {(_g = (_f = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.authoring) === null || _f === void 0 ? void 0 : _f.rules) === null || _g === void 0 ? void 0 : _g.map((rule, ruleIndex) => {
            var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
            return (<div key={`${rule.id}-${ruleIndex}`} className={`card${rule.correct ? ' correct' : ' incorrect'}`}>
            <div className="card-header p-2" id={`heading${ruleIndex}`}>
              <h2 className="mb-0">
                <button className="btn btn-link btn-block text-left" type="button" data-toggle="collapse" data-target={`#collapse${ruleIndex}`} aria-expanded={expandedRules[`rule-${ruleIndex}`]} aria-controls={`collapse${ruleIndex}`} onClick={(e) => setExpandedRules(Object.assign(Object.assign({}, expandedRules), { [`rule-${ruleIndex}`]: !expandedRules[`rule-${ruleIndex}`] }))}>
                  <span className={`chevron-arrow mr-2${expandedRules[`rule-${ruleIndex}`] ? ' rotate' : ''}`}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                      <path fillRule="evenodd" d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"/>
                    </svg>
                  </span>
                  {rule.name}
                </button>
              </h2>
            </div>
            <div id={`collapse${ruleIndex}`} className="collapse" aria-labelledby={`heading${ruleIndex}`}>
              <div className="mt-2 pt-2 px-3 font-weight-bold text-uppercase">Conditions</div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {/* Conditions for ALL */}
                  {hasOwnProperty(rule.conditions, 'all') && (<>
                      {((_b = (_a = rule.conditions) === null || _a === void 0 ? void 0 : _a.all) === null || _b === void 0 ? void 0 : _b.length) === 0 && (<li className="list-group-item">
                          No conditions. This rule will always fire.
                        </li>)}
                      {((_d = (_c = rule.conditions) === null || _c === void 0 ? void 0 : _c.all) === null || _d === void 0 ? void 0 : _d.length) > 0 &&
                        rule.conditions.all.map((condition, conditionIndex) => (<li key={conditionIndex} className="list-group-item">
                            {`${condition.fact} ${condition.operator} ${JSON.stringify(condition.value)}`}
                          </li>))}
                    </>)}
                  {/* Conditions for ANY */}
                  {hasOwnProperty(rule.conditions, 'any') && (<>
                      {((_f = (_e = rule.conditions) === null || _e === void 0 ? void 0 : _e.any) === null || _f === void 0 ? void 0 : _f.length) === 0 && (<li className="list-group-item">
                          No conditions. This rule will always fire.
                        </li>)}
                      {((_h = (_g = rule.conditions) === null || _g === void 0 ? void 0 : _g.any) === null || _h === void 0 ? void 0 : _h.length) > 0 &&
                        rule.conditions.any.map((condition, conditionIndex) => (<li key={conditionIndex} className="list-group-item">
                            {`${condition.fact} ${condition.operator} ${JSON.stringify(condition.value)}`}
                          </li>))}
                    </>)}
                </ul>
              </div>
              <div className="d-flex justify-content-between align-items-center px-3 font-weight-bold text-uppercase">
                Actions{' '}
                <button onClick={(e) => triggerAction(e, rule)} type="button" className="btn btn-sm btn-outline-primary d-flex px-1">
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                    <path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 010 1.393z"/>
                  </svg>
                </button>
              </div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {((_l = (_k = (_j = rule.event) === null || _j === void 0 ? void 0 : _j.params) === null || _k === void 0 ? void 0 : _k.actions) === null || _l === void 0 ? void 0 : _l.length) === 0 && (<li className="list-group-item">No actions assigned.</li>)}
                  {((_p = (_o = (_m = rule.event) === null || _m === void 0 ? void 0 : _m.params) === null || _o === void 0 ? void 0 : _o.actions) === null || _p === void 0 ? void 0 : _p.length) > 0 &&
                    rule.event.params.actions.map((action, actionIndex) => (<li key={actionIndex} className="list-group-item">
                        <span className="text-capitalize">{action.type}</span>
                      </li>))}
                </ul>
              </div>
            </div>
          </div>);
        })}
      </div>
    </div>);
};
export default Adaptivity;
//# sourceMappingURL=Adaptivity.jsx.map