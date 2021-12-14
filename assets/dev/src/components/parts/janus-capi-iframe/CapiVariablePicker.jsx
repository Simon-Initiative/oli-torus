/* eslint-disable react/react-in-jsx-scope */
import { useState } from 'react';
import AutoDetectInput from '../../../../src/apps/delivery/components/preview-tools/inspector/AutoDetectInput';
const CapiVariablePicker = ({ label, state, onChange, onSave, onCancel, showSaveCancelButtons = false, }) => {
    const [changeOperations, setChangeOperations] = useState([]);
    const [expandedPanels, setExpandedPanels] = useState([]);
    const handleValueChange = (changeOp) => {
        onChange(changeOp);
    };
    const handleApplyChanges = () => {
        onSave([]);
    };
    const handleCancelChanges = (e) => {
        setChangeOperations([]);
        onCancel(changeOperations);
    };
    return state.length > 0 ? (<div>
      {showSaveCancelButtons && (<div className="apply-changes btn-group-sm p-2" role="group" aria-label="Apply changes">
          <button type="button" className="btn btn-secondary mr-1" onClick={handleCancelChanges}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary ml-1" onClick={handleApplyChanges}>
            Save
          </button>
        </div>)}
      <div id={`collapseRoot${label}`} className={`${expandedPanels[`panel-Root${label}`] ? '' : 'visually-hidden'}`} aria-labelledby={`headingRoot${label}`} style={{ maxWidth: 450, overflowY: 'auto', maxHeight: 450 }}>
        <div className="card-body py-2">
          <ul className="list-group list-group-flush">
            {state.sort().map((level1, index) => {
            return (level1 && (<li key={`leaf-${level1}${index}`} className="list-group-item pr-0">
                    <div className="user-input" style={{ display: 'flex', alignItems: 'center' }}>
                      <span className="stateKey" style={{
                    display: 'flex',
                    alignItems: 'center',
                    flex: '1 0 60%',
                    whiteSpace: 'nowrap',
                    textOverflow: 'ellipsis',
                    overflow: 'hidden',
                }} title={level1.key}>
                        {level1.key}
                      </span>
                      <AutoDetectInput label={level1.key} value={level1} state={state} onChange={handleValueChange}/>
                    </div>
                  </li>));
        })}
          </ul>
        </div>
      </div>
    </div>) : null;
};
export default CapiVariablePicker;
//# sourceMappingURL=CapiVariablePicker.jsx.map