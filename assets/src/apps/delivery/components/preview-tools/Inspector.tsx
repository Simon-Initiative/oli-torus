/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { v4 as uuidv4 } from 'uuid';
import { CapiVariable, CapiVariableTypes, parseCapiValue } from '../../../../adaptivity/capi';
import {
  ApplyStateOperation,
  defaultGlobalEnv,
  getEnvState,
} from '../../../../adaptivity/scripting';
import { applyStateChange } from '../../store/features/adaptivity/actions/applyStateChange';
import { selectCurrentActivityTree } from '../../store/features/groups/selectors/deck';

interface InspectorProps {
  currentActivity: any;
}
// Inspector Placeholder
const Inspector: React.FC<InspectorProps> = ({ currentActivity }) => {
  const dispatch = useDispatch();

  const [globalState, setGlobalState] = useState<any>(null);
  const [globalInputState, setGlobalInputState] = useState<any>({});
  const [sessionState, setSessionState] = useState<any>({});
  const [stageState, setStageState] = useState<any>({});

  // TODO: technically this tree concept only exists in the DECK layout
  // another layout like single activity or stacked might not have layers to deal with
  // so need to create some kind of generic layout method to get the needed info instead
  // well actually the preview tools might only apply to deck layout
  const currentActivityTree = useSelector(selectCurrentActivityTree);

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
    const sessionSlice = { ...statePuff['session'] };
    console.log('SESSION STATE PUFF', { statePuff, sessionSlice });
    return setSessionState(sessionSlice);
  };

  const getStageState = (): any => {
    const statePuff: any = unflatten(globalState);
    const stageSlice = currentActivityTree?.reduce((collect: any, activity) => {
      const next = { ...collect, ...statePuff[`${activity.id}|stage`] };
      return next;
    }, {});
    console.log('STAGE STATE PUFF', { statePuff, stageSlice });
    return setStageState(stageSlice);
  };

  // change handler fires for every key, and there are often several at once
  const debounceStateChanges = useCallback(
    debounce(() => {
      const allState = getEnvState(defaultGlobalEnv);
      const globalStateAsVars = Object.keys(allState).reduce((collect: any, key) => {
        collect[key] = new CapiVariable({ key, value: allState[key] });
        return collect;
      }, {});
      setGlobalState(globalStateAsVars);
    }, 50),
    [],
  );

  useEffect(() => {
    setStageState({});
    setSessionState({});
    debounceStateChanges();
    defaultGlobalEnv.addListener('change', debounceStateChanges);
    return () => {
      defaultGlobalEnv.removeListener('change', debounceStateChanges);
    };
  }, [currentActivityTree]);

  useEffect(() => {
    if (!globalState) {
      return;
    }
    getSessionState();
    getStageState();
  }, [globalState]);

  interface AutoDetectInputProps {
    label: string;
    value: any;
    state?: any;
    // onChange: ()=>void;
  }
  const AutoDetectInput: React.FC<AutoDetectInputProps> = ({ label, value, state }): any => {
    /* console.log('🚀 > file: PreviewTools.tsx > line 390 > { label, value ,state}', {
      label,
      value,
      state,
    }); */
    const theValue = value as CapiVariable;

    const handleValueChange = (e, isCheckbox = false) => {
      if (e.type === 'keydown' && e.key !== 'Enter') {
        return;
      }
      console.log('VALUE CHANGE INSPECTOR', e, e.target.value, theValue);
      const newValue = isCheckbox ? e.target.checked : e.target.value;
      theValue.value = newValue;
      const applyOp: ApplyStateOperation = {
        target: theValue.key,
        operator: '=',
        type: theValue.type,
        value: parseCapiValue(theValue),
      };
      dispatch(applyStateChange({ operations: [applyOp] }));
    };

    const uuid = uuidv4();
    switch (theValue.type) {
      case CapiVariableTypes.BOOLEAN:
        return (
          <div className="custom-control custom-switch">
            <input
              type="checkbox"
              className="custom-control-input"
              id={uuid}
              defaultChecked={parseCapiValue(theValue)}
              onChange={(e) => handleValueChange(e, true)}
            />
            <label className="custom-control-label" htmlFor={uuid}></label>
          </div>
        );

      case CapiVariableTypes.NUMBER:
        return (
          <input
            type="number"
            className="input-group-sm stateValue"
            aria-label={label}
            defaultValue={parseCapiValue(theValue)}
            onKeyDown={handleValueChange}
          />
        );

      case CapiVariableTypes.ARRAY:
      case CapiVariableTypes.ARRAY_POINT:
        // TODO: fancy array editor??
        return (
          <input
            type="text"
            className="input-group-sm stateValue"
            aria-label={label}
            defaultValue={JSON.stringify(parseCapiValue(theValue))}
            onKeyDown={handleValueChange}
          />
        );

      case CapiVariableTypes.ENUM:
        return (
          // TODO : wire this up
          <div className="user-input">
            <span className="stateKey" title="session.visits.q:1541198781354:733">
              q:1541198781354:733
            </span>
            {/* Dropdown example */}
            <select className="custom-select custom-select-sm" defaultValue="3">
              <option value="1">One</option>
              <option value="2">Two</option>
              <option value="3">Three</option>
              <option value="4">
                This option has a very long text node that may stretch out the drop down. What
                happens?
              </option>
            </select>
          </div>
        );

      default:
        return (
          <input
            type="text"
            className="input-group-sm stateValue"
            aria-label={label}
            defaultValue={theValue.value}
            onKeyDown={handleValueChange}
          />
        );
    }
  };

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
    const [expandedPanels, setExpandedPanels]: any = useState({});
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
            // data-target={`#collapse${rootLevel}${levelIndex}`}
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
            expandedPanels[`panel-${rootLevel}${levelIndex}`] ? '' : 'visually-hidden'
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
                        <AutoDetectInput
                          label={level2}
                          value={state[rootLevel][level2]}
                          state={{ ...state[rootLevel] }}
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
    const [expandedPanels, setExpandedPanels]: any = useState({});

    return Object.keys(state).length > 0 ? (
      <div className="card even">
        <div className="card-header p-2" id={`headingRoot${label}`}>
          <h2 className="mb-0">
            <button
              className="btn btn-link btn-block text-left"
              type="button"
              // data-toggle="collapse"
              // data-target={`#collapseRoot${label}`}
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
          className={`${expandedPanels[`panel-Root${label}`] ? '' : 'visually-hidden'}`}
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
                        <AutoDetectInput label={level1} value={state[level1]} state={state} />
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
    ) : null;
  };

  return (
    <div className="inspector">
      <div className="accordion">
        <StateDisplay label="Session" state={sessionState} />
        <StateDisplay label="Stage" state={stageState} />
      </div>
    </div>
  );
};

export default Inspector;
