/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import { defaultGlobalEnv, getEnvState } from '../../../adaptivity/scripting';
import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../store/features/activities/slice';
import { triggerCheck } from '../store/features/adaptivity/actions/triggerCheck';
import { setLastCheckResults } from '../store/features/adaptivity/slice';
import { navigateToActivity } from '../store/features/groups/actions/deck';

// Title Component
interface TitleProps {
  title: string;
  togglePanel: () => void;
}
const Title: React.FC<any> = (props: TitleProps) => {
  const { title, togglePanel } = props;
  return (
    <div className="pt-header">
      <button onClick={() => togglePanel()}>
        <svg
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          height="24"
          viewBox="0 0 14 14"
          width="24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M4.646 4.646a.5.5 0 01.708 0L8 7.293l2.646-2.647a.5.5 0 01.708.708L8.707 8l2.647 2.646a.5.5 0 01-.708.708L8 8.707l-2.646 2.647a.5.5 0 01-.708-.708L7.293 8 4.646 5.354a.5.5 0 010-.708z" />
        </svg>
      </button>
      <div>
        {/* TODO: Convert to ENUM */}
        {title === 'Screens' && <ScreensIcon />}
        {title === 'Adaptivity' && <AdaptivityIcon />}
        {title === 'Inspector' && <InspectorIcon />}
        <div className="pt-title">{title}</div>
      </div>
    </div>
  );
};

// Screen Selector View
interface ScreenSelectorProps {
  sequence: any;
  navigate: any;
  currentActivity: any;
}
const ScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  currentActivity,
}: ScreenSelectorProps) => {
  return (
    <div className={`preview-tools-view`}>
      <ol className="list-group list-group-flush">
        {sequence?.map((s: any, i: number) => {
          return (
            <li
              key={i}
              className={`list-group-item pl-5 py-1 list-group-item-action${
                currentActivity?.id === s.sequenceId ? ' active' : ''
              }`}
            >
              <a
                href=""
                className={currentActivity?.id === s.sequenceId ? 'selected' : ''}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(s.sequenceId);
                }}
              >
                {s.sequenceName}
              </a>
            </li>
          );
        })}
      </ol>
    </div>
  );
};

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
  const hasOwnProperty = (obj: any, property: string) =>
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

interface InspectorProps {
  currentActivity: any;
}
// Inspector Placeholder
const Inspector: React.FC<InspectorProps> = ({ currentActivity }) => {
  const [globalState, setGlobalState] = useState<any>({});
  const [expandedPanels, setExpandedPanels]: any = useState({});
  const [sessionState, setSessionState] = useState<any>({});
  const [stageState, setStageState] = useState<any>({});

  const unflatten = (data: any) => {
    // https://stackoverflow.com/questions/42694980/how-to-unflatten-a-javascript-object-in-a-daisy-chain-dot-notation-into-an-objec
    const result = {};
    for (const i in data) {
      const keys = i.split('.');
      keys.reduce(function (r: any, e: any, j) {
        return (
          r[e] || (r[e] = isNaN(Number(keys[j + 1])) ? (keys.length - 1 == j ? data[i] : {}) : [])
        );
      }, result);
    }
    return result;
  };
  const isArray = (array: any) => {
    return !!array && array.constructor === Array;
  };
  const isObject = (object: any) => {
    return !!object && object.constructor === Object;
  };
  const hasNesting: any = (thing: any) => {
    if (isObject(thing) && Object.keys(thing).length > 0) {
      return true;
    }
    if (isArray(thing) && thing.length > 0) {
      return true;
    }
    return false;
  };

  const getSessionState = (): any => {
    const statePuff: any = unflatten(globalState);
    return setSessionState({ ...statePuff['session'] });
  };

  const getStageState = (): any => {
    const statePuff: any = unflatten(globalState);
    return setStageState({ ...statePuff[`${currentActivity.id}|stage`] });
  };

  useEffect(() => {
    setStageState({});
    setSessionState({});
    setExpandedPanels({});
    setTimeout(() => {
      // TODO : figure out a better way to setGlobalState AFTER state reset to fix timing jank
      setGlobalState(getEnvState(defaultGlobalEnv));
    }, 50);
  }, [currentActivity]);

  useEffect(() => {
    getSessionState();
    getStageState();
  }, [globalState]);

  interface NestedStateDisplayProps {
    rootLevel: any;
    levelIndex: number;
    state: any;
  }
  const NestedStateDisplay: React.FC<NestedStateDisplayProps> = ({
    rootLevel,
    levelIndex,
    state,
  }) => {
    return (
      <li key={`leaf-branch-${rootLevel}${levelIndex}`} className="list-group-item is-parent">
        {/* TODO Toggle even / odd based on index */}
        <div
          className="card-header p-0 m-0 rounded-lg mt-2 even"
          id={`heading${rootLevel}${levelIndex}`}
        >
          <button
            className="btn btn-link btn-block text-left"
            type="button"
            // TODO: figure out why Bootstrap collapse is breaking in recursion
            // data-toggle="collapse"
            data-target={`#collapse${rootLevel}${levelIndex}`}
            aria-expanded={expandedPanels[`panel-${rootLevel}${levelIndex}`]}
            aria-controls={`collapse${rootLevel}${levelIndex}`}
            onClick={() =>
              setExpandedPanels({
                ...expandedPanels,
                [`panel-${rootLevel}${levelIndex}`]: !expandedPanels[
                  `panel-${rootLevel}${levelIndex}`
                ],
              })
            }
          >
            <span
              className={`chevron-arrow mr-2${
                expandedPanels[`panel-${rootLevel}${levelIndex}`] ? ' rotate' : ''
              }`}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                <path
                  fillRule="evenodd"
                  d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"
                />
              </svg>
            </span>
            {rootLevel}
          </button>
        </div>
        <div
          id={`collapse${rootLevel}${levelIndex}`}
          // TODO: reset className to 'collapse' after figuring out Bootstrap recursion issue
          className={`${
            expandedPanels[`panel-${rootLevel}${levelIndex}`] ? 'collapse show' : 'collapse'
          }`}
          aria-labelledby={`heading${rootLevel}${levelIndex}`}
        >
          <ul className="list-group list-group-flush">
            {state[rootLevel] &&
              Object.keys(state[rootLevel])
                .sort()
                .map((level2: any) =>
                  !hasNesting(state[rootLevel][level2]) ? (
                    <li key={`flat-${level2}${levelIndex + 1}`} className="list-group-item pr-0">
                      <div className="user-input">
                        <span className="stateKey" title={level2}>
                          {level2}
                        </span>
                        <input
                          type="text"
                          className="input-group-sm stateValue"
                          aria-label={level2}
                          defaultValue={JSON.stringify(state[rootLevel][level2])}
                        />
                      </div>
                    </li>
                  ) : (
                    <NestedStateDisplay
                      key={`${level2}${levelIndex + 1}`}
                      rootLevel={level2}
                      levelIndex={levelIndex + 1}
                      state={{ [level2]: { ...state[rootLevel][level2] } }}
                    />
                  ),
                )}
          </ul>
        </div>
      </li>
    );
  };

  interface StateDisplayProps {
    label: string;
    state: any;
  }
  const StateDisplay: React.FC<StateDisplayProps> = ({ label, state }) => {
    return (
      <div className="card even">
        <div className="card-header p-2" id={`headingRoot${label}`}>
          <h2 className="mb-0">
            <button
              className="btn btn-link btn-block text-left"
              type="button"
              // data-toggle="collapse"
              data-target={`#collapseRoot${label}`}
              aria-expanded={expandedPanels[`panel-Root${label}`]}
              aria-controls={`collapseRoot${label}`}
              onClick={() =>
                setExpandedPanels({
                  ...expandedPanels,
                  [`panel-Root${label}`]: !expandedPanels[`panel-Root${label}`],
                })
              }
            >
              <span
                className={`chevron-arrow mr-2${
                  expandedPanels[`panel-Root${label}`] ? ' rotate' : ''
                }`}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                  <path
                    fillRule="evenodd"
                    d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"
                  />
                </svg>
              </span>
              {label}
            </button>
          </h2>
        </div>
        <div
          id={`collapseRoot${label}`}
          className={`${expandedPanels[`panel-Root${label}`] ? 'collapse show' : 'collapse'}`}
          aria-labelledby={`headingRoot${label}`}
        >
          <div className="card-body py-2">
            <ul className="list-group list-group-flush">
              {Object.keys(state)
                .sort()
                .map((level1: any, index: number) =>
                  !hasNesting(state[level1]) ? (
                    <li key={`leaf-${level1}${index}`} className="list-group-item pr-0">
                      <div className="user-input">
                        <span className="stateKey" title={level1}>
                          {level1}
                        </span>
                        <input
                          type="text"
                          className="input-group-sm stateValue"
                          aria-label={level1}
                          defaultValue={JSON.stringify(state[level1])}
                        />
                      </div>
                    </li>
                  ) : (
                    <NestedStateDisplay
                      key={`${level1}${index}`}
                      rootLevel={level1}
                      levelIndex={1}
                      state={state}
                    />
                  ),
                )}
            </ul>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="inspector">
      <div className="accordion">
        {Object.keys(sessionState).length > 0 && (
          <StateDisplay label="Session" state={sessionState} />
        )}
        {Object.keys(stageState).length > 0 && <StateDisplay label="Stage" state={stageState} />}
      </div>
    </div>
  );
};

// Reusable Icons
const ScreensIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M0 4s0-2 2-2h12s2 0 2 2v6s0 2-2 2h-4c0 .667.083 1.167.25 1.5H11a.5.5 0 010 1H5a.5.5 0 010-1h.75c.167-.333.25-.833.25-1.5H2s-2 0-2-2V4zm1.398-.855a.758.758 0 00-.254.302A1.46 1.46 0 001 4.01V10c0 .325.078.502.145.602.07.105.17.188.302.254a1.464 1.464 0 00.538.143L2.01 11H14c.325 0 .502-.078.602-.145a.758.758 0 00.254-.302 1.464 1.464 0 00.143-.538L15 9.99V4c0-.325-.078-.502-.145-.602a.757.757 0 00-.302-.254A1.46 1.46 0 0013.99 3H2c-.325 0-.502.078-.602.145z" />
  </svg>
);

const AdaptivityIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      fillRule="evenodd"
      d="M6 3.5A1.5 1.5 0 017.5 2h1A1.5 1.5 0 0110 3.5v1A1.5 1.5 0 018.5 6v1H14a.5.5 0 01.5.5v1a.5.5 0 01-1 0V8h-5v.5a.5.5 0 01-1 0V8h-5v.5a.5.5 0 01-1 0v-1A.5.5 0 012 7h5.5V6A1.5 1.5 0 016 4.5v-1zM8.5 5a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1zM0 11.5A1.5 1.5 0 011.5 10h1A1.5 1.5 0 014 11.5v1A1.5 1.5 0 012.5 14h-1A1.5 1.5 0 010 12.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1zm4.5.5A1.5 1.5 0 017.5 10h1a1.5 1.5 0 011.5 1.5v1A1.5 1.5 0 018.5 14h-1A1.5 1.5 0 016 12.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1zm4.5.5a1.5 1.5 0 011.5-1.5h1a1.5 1.5 0 011.5 1.5v1a1.5 1.5 0 01-1.5 1.5h-1a1.5 1.5 0 01-1.5-1.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1z"
    />
  </svg>
);

const InspectorIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M10.478 1.647a.5.5 0 10-.956-.294l-4 13a.5.5 0 00.956.294l4-13zM4.854 4.146a.5.5 0 010 .708L1.707 8l3.147 3.146a.5.5 0 01-.708.708l-3.5-3.5a.5.5 0 010-.708l3.5-3.5a.5.5 0 01.708 0zm6.292 0a.5.5 0 000 .708L14.293 8l-3.147 3.146a.5.5 0 00.708.708l3.5-3.5a.5.5 0 000-.708l-3.5-3.5a.5.5 0 00-.708 0z" />
  </svg>
);

// Primary Preview Tools component
interface PreviewToolsProps {
  model: any;
}
const PreviewTools: React.FC<PreviewToolsProps> = ({ model }) => {
  const [opened, setOpened] = useState<boolean>(false);
  const [view, setView] = useState<string>('screens');
  const currentActivity = useSelector(selectCurrentActivity);
  const dispatch = useDispatch();
  const sequence = model[0].children
    ?.filter((child: any) => !child.custom.isLayer && !child.custom.isBank)
    .map((s: any) => {
      return { ...s.custom };
    });

  // Navigates to Activity
  const navigate = (activityId: any) => {
    dispatch(navigateToActivity(activityId));
  };

  // Toggle the menu open/closed
  const togglePanel = () => {
    setOpened(!opened);
  };

  // Fires when selecting a tool to open
  const displayView = (view: any) => {
    setView(view);
    setOpened(true);
  };

  return (
    <div id="PreviewTools" className={`preview-tools${opened ? ' opened' : ''}`}>
      {opened && (
        <Title togglePanel={togglePanel} title={view.charAt(0).toUpperCase() + view.slice(1)} />
      )}

      <div className="pt-body">
        {!opened && (
          <div className="action-picker">
            <button
              onClick={() => displayView('screens')}
              className="mb-2"
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <ScreensIcon />
            </button>
            <button
              onClick={() => displayView('adaptivity')}
              className="mb-2"
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <AdaptivityIcon />
            </button>
            <button
              onClick={() => displayView('inspector')}
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <InspectorIcon />
            </button>
          </div>
        )}
        {opened && view === 'screens' && (
          <ScreenSelector
            sequence={sequence}
            navigate={navigate}
            currentActivity={currentActivity}
          />
        )}
        {opened && view === 'adaptivity' && <Adaptivity currentActivity={currentActivity} />}
        {opened && view === 'inspector' && <Inspector currentActivity={currentActivity} />}
      </div>
    </div>
  );
};

export default PreviewTools;
