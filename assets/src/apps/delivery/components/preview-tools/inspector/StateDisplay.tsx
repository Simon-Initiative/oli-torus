/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React, { useCallback, useState } from 'react';
import { ApplyStateOperation } from '../../../../../adaptivity/scripting';
import AutoDetectInput from './AutoDetectInput';
import NestedStateDisplay from './NestedStateDisplay';
import { hasNesting } from './utils';

interface StateDisplayProps {
  label: string;
  state: any;
  onChange?: (changeOp: ApplyStateOperation) => void;
}
const StateDisplay: React.FC<StateDisplayProps> = ({ label, state, onChange }) => {
  const [expandedPanels, setExpandedPanels]: any = useState({});
  const handleValueChange = useCallback(
    (changeOp: ApplyStateOperation) => {
      /* console.log('STATE DISPLAY CHANGE BUBBLE', { changeOp }); */
      if (onChange) {
        onChange(changeOp);
      }
    },
    [onChange],
  );

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
                      <AutoDetectInput
                        label={level1}
                        value={state[level1]}
                        state={state}
                        onChange={handleValueChange}
                      />
                    </div>
                  </li>
                ) : (
                  <NestedStateDisplay
                    key={`${level1}${index}`}
                    rootLevel={level1}
                    levelIndex={1}
                    state={state}
                    onChange={handleValueChange}
                  />
                ),
              )}
          </ul>
        </div>
      </div>
    </div>
  ) : null;
};

export default StateDisplay;
