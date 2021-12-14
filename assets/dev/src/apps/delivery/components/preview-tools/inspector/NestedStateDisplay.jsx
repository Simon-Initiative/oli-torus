/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React, { useCallback, useState } from 'react';
import AutoDetectInput from './AutoDetectInput';
import { hasNesting } from './utils';
const NestedStateDisplay = ({ rootLevel, levelIndex, state, onChange, }) => {
    const [expandedPanels, setExpandedPanels] = useState({});
    const handleValueChange = useCallback((changeOp) => {
        /* console.log('NESTED CHANGE BUBBLE', { changeOp }); */
        if (onChange) {
            onChange(changeOp);
        }
    }, [onChange]);
    return (<li key={`leaf-branch-${rootLevel}${levelIndex}`} className="list-group-item is-parent">
      {/* TODO Toggle even / odd based on index */}
      <div className="card-header p-0 m-0 rounded-lg mt-2 even" id={`heading${rootLevel}${levelIndex}`}>
        <button className="btn btn-link btn-block text-left" type="button" 
    // TODO: figure out why Bootstrap collapse is breaking in recursion
    // data-toggle="collapse"
    // data-target={`#collapse${rootLevel}${levelIndex}`}
    aria-expanded={expandedPanels[`panel-${rootLevel}${levelIndex}`]} aria-controls={`collapse${rootLevel}${levelIndex}`} onClick={() => setExpandedPanels(Object.assign(Object.assign({}, expandedPanels), { [`panel-${rootLevel}${levelIndex}`]: !expandedPanels[`panel-${rootLevel}${levelIndex}`] }))}>
          <span className={`chevron-arrow mr-2${expandedPanels[`panel-${rootLevel}${levelIndex}`] ? ' rotate' : ''}`}>
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
              <path fillRule="evenodd" d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"/>
            </svg>
          </span>
          {rootLevel}
        </button>
      </div>
      <div id={`collapse${rootLevel}${levelIndex}`} 
    // TODO: reset className to 'collapse' after figuring out Bootstrap recursion issue
    className={`${expandedPanels[`panel-${rootLevel}${levelIndex}`] ? '' : 'visually-hidden'}`} aria-labelledby={`heading${rootLevel}${levelIndex}`}>
        <ul className="list-group list-group-flush">
          {state[rootLevel] &&
            Object.keys(state[rootLevel])
                .sort()
                .map((level2) => !hasNesting(state[rootLevel][level2]) ? (<li key={`flat-${level2}${levelIndex + 1}`} className="list-group-item pr-0">
                    <div className="user-input">
                      <span className="stateKey" title={level2}>
                        {level2}
                      </span>
                      <AutoDetectInput label={level2} value={state[rootLevel][level2]} state={Object.assign({}, state[rootLevel])} onChange={handleValueChange}/>
                    </div>
                  </li>) : (<NestedStateDisplay key={`${level2}${levelIndex + 1}`} rootLevel={level2} levelIndex={levelIndex + 1} state={{ [level2]: Object.assign({}, state[rootLevel][level2]) }} onChange={handleValueChange}/>))}
        </ul>
      </div>
    </li>);
};
export default NestedStateDisplay;
//# sourceMappingURL=NestedStateDisplay.jsx.map