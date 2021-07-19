/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React, { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { triggerCheck } from '../../store/features/adaptivity/actions/triggerCheck';
import { setLastCheckResults } from '../../store/features/adaptivity/slice';

interface AdaptivityProps {
  currentActivity: any;
}
// Adaptivity Placeholder
const Adaptivity: React.FC<AdaptivityProps> = ({ currentActivity }) => {
  const [expandedRules, setExpandedRules]: any = useState({});
  const dispatch = useDispatch();

  const triggerAction = async (e: any, rule: any) => {
    e.preventDefault();

    // Strip out any rules that are not the selected rule
    const customRules = currentActivity.authoring?.rules?.filter(
      (activityRule: any) => activityRule.id === rule.id,
    );
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
    await dispatch(setLastCheckResults({ results: customCheckResults }));
  };

  useEffect(() => {
    setExpandedRules({});
  }, [currentActivity]);

  // helper because of lint
  const hasOwnProperty = (obj: unknown, property: string) =>
    Object.prototype.hasOwnProperty.call(obj || {}, property);

  return (
    <div className="adaptivity">
      <div className="accordion">
        {/* InitState */}
        {currentActivity?.content?.custom?.facts?.length > 0 && (
          <div key={`init-${currentActivity.id}`} className="card initState">
            <div className="card-header p-2" id={`initHeading-${currentActivity.id}`}>
              <h2 className="mb-0">
                <button
                  className="btn btn-link btn-block text-left"
                  type="button"
                  data-toggle="collapse"
                  data-target={`#collapse`}
                  aria-expanded={expandedRules[`initState-${currentActivity.id}`]}
                  aria-controls={`collapse`}
                  onClick={(e) =>
                    setExpandedRules({
                      ...expandedRules,
                      [`initState-${currentActivity.id}`]: !expandedRules[
                        `initState-${currentActivity.id}`
                      ],
                    })
                  }
                >
                  <span
                    className={`chevron-arrow mr-2${
                      expandedRules[`initState-${currentActivity.id}`] ? ' rotate' : ''
                    }`}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="16"
                      height="16"
                      fill="currentColor"
                    >
                      <path
                        fillRule="evenodd"
                        d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"
                      />
                    </svg>
                  </span>
                  Initial State
                </button>
              </h2>
            </div>
            <div
              id={`collapse`}
              className="collapse"
              aria-labelledby={`initHeading-${currentActivity.id}`}
            >
              <div className="mt-2 pt-2 px-3 font-weight-bold text-uppercase">Facts</div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {currentActivity?.content?.custom?.facts.map((fact: any, factIndex: number) => (
                    <li key={factIndex} className="list-group-item">{`${fact.target} ${
                      fact.operator
                    } ${JSON.stringify(fact.value)}`}</li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        )}
        {/* Rules */}
        {currentActivity?.authoring?.rules?.map((rule: any, ruleIndex: number) => (
          <div
            key={`${rule.id}-${ruleIndex}`}
            className={`card${rule.correct ? ' correct' : ' incorrect'}`}
          >
            <div className="card-header p-2" id={`heading${ruleIndex}`}>
              <h2 className="mb-0">
                <button
                  className="btn btn-link btn-block text-left"
                  type="button"
                  data-toggle="collapse"
                  data-target={`#collapse${ruleIndex}`}
                  aria-expanded={expandedRules[`rule-${ruleIndex}`]}
                  aria-controls={`collapse${ruleIndex}`}
                  onClick={(e) =>
                    setExpandedRules({
                      ...expandedRules,
                      [`rule-${ruleIndex}`]: !expandedRules[`rule-${ruleIndex}`],
                    })
                  }
                >
                  <span
                    className={`chevron-arrow mr-2${
                      expandedRules[`rule-${ruleIndex}`] ? ' rotate' : ''
                    }`}
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="16"
                      height="16"
                      fill="currentColor"
                    >
                      <path
                        fillRule="evenodd"
                        d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"
                      />
                    </svg>
                  </span>
                  {rule.name}
                </button>
              </h2>
            </div>
            <div
              id={`collapse${ruleIndex}`}
              className="collapse"
              aria-labelledby={`heading${ruleIndex}`}
            >
              <div className="mt-2 pt-2 px-3 font-weight-bold text-uppercase">Conditions</div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {/* Conditions for ALL */}
                  {hasOwnProperty(rule.conditions, 'all') && (
                    <>
                      {rule.conditions?.all?.length === 0 && (
                        <li className="list-group-item">
                          No conditions. This rule will always fire.
                        </li>
                      )}
                      {rule.conditions?.all?.length > 0 &&
                        rule.conditions.all.map((condition: any, conditionIndex: number) => (
                          <li key={conditionIndex} className="list-group-item">
                            {`${condition.fact} ${condition.operator} ${JSON.stringify(
                              condition.value,
                            )}`}
                          </li>
                        ))}
                    </>
                  )}
                  {/* Conditions for ANY */}
                  {hasOwnProperty(rule.conditions, 'any') && (
                    <>
                      {rule.conditions?.any?.length === 0 && (
                        <li className="list-group-item">
                          No conditions. This rule will always fire.
                        </li>
                      )}
                      {rule.conditions?.any?.length > 0 &&
                        rule.conditions.any.map((condition: any, conditionIndex: number) => (
                          <li key={conditionIndex} className="list-group-item">
                            {`${condition.fact} ${condition.operator} ${JSON.stringify(
                              condition.value,
                            )}`}
                          </li>
                        ))}
                    </>
                  )}
                </ul>
              </div>
              <div className="d-flex justify-content-between align-items-center px-3 font-weight-bold text-uppercase">
                Actions{' '}
                <button
                  onClick={(e) => triggerAction(e, rule)}
                  type="button"
                  className="btn btn-sm btn-outline-primary d-flex px-1"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    fill="currentColor"
                  >
                    <path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 010 1.393z" />
                  </svg>
                </button>
              </div>
              <div className="card-body pt-2">
                <ul className="list-group">
                  {rule.event?.params?.actions?.length === 0 && (
                    <li className="list-group-item">No actions assigned.</li>
                  )}
                  {rule.event?.params?.actions?.length > 0 &&
                    rule.event.params.actions.map((action: any, actionIndex: number) => (
                      <li key={actionIndex} className="list-group-item">
                        <span className="text-capitalize">{action.type}</span>
                      </li>
                    ))}
                </ul>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Adaptivity;
