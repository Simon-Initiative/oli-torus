/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import React from 'react';
const ScreenSelector = ({ sequence, navigate, currentActivity, }) => {
    return (<div className={`preview-tools-view`}>
      <ol className="list-group list-group-flush">
        {sequence === null || sequence === void 0 ? void 0 : sequence.map((s, i) => {
            return (<li key={i} className={`list-group-item pl-5 py-1 list-group-item-action${(currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.id) === s.sequenceId ? ' active' : ''}`}>
              <a href="" className={(currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.id) === s.sequenceId ? 'selected' : ''} onClick={(e) => {
                    e.preventDefault();
                    navigate(s.sequenceId);
                }}>
                {s.sequenceName}
              </a>
            </li>);
        })}
      </ol>
    </div>);
};
export default ScreenSelector;
//# sourceMappingURL=ScreenSelector.jsx.map