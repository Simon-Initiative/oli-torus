/* eslint-disable react/react-in-jsx-scope */
import { useCallback, useState } from 'react';
import { ApplyStateOperation } from 'adaptivity/scripting';
import AutoDetectInput from '../../../../src/apps/delivery/components/preview-tools/inspector/AutoDetectInput';

interface StateDisplayProps {
  label: string;
  state: any;
  onChange: (changeOp: ApplyStateOperation) => void;
  onSave: (changeOp: ApplyStateOperation[]) => void;
  onCancel: (changeOp: ApplyStateOperation[]) => void;
  showSaveCancelButtons?: boolean;
}
const CapiVariablePicker: React.FC<StateDisplayProps> = ({
  label,
  state,
  onChange,
  onSave,
  onCancel,
  showSaveCancelButtons = false,
}) => {
  const [changeOperations, setChangeOperations] = useState<ApplyStateOperation[]>([]);
  const [expandedPanels, setExpandedPanels]: any = useState([]);
  const handleValueChange = (changeOp: ApplyStateOperation) => {
    onChange(changeOp);
  };

  const handleApplyChanges = () => {
    onSave([]);
  };

  const handleCancelChanges = (e: any) => {
    setChangeOperations([]);
    onCancel(changeOperations);
  };

  return state.length > 0 ? (
    <div>
      {showSaveCancelButtons && (
        <div className="apply-changes btn-group-sm p-2" role="group" aria-label="Apply changes">
          <button type="button" className="btn btn-secondary mr-1" onClick={handleCancelChanges}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary ml-1" onClick={handleApplyChanges}>
            Save
          </button>
        </div>
      )}
      <div
        id={`collapseRoot${label}`}
        className={`${expandedPanels[`panel-Root${label}`] ? '' : 'visually-hidden'}`}
        aria-labelledby={`headingRoot${label}`}
        style={{ maxWidth: 450, overflowY: 'auto', maxHeight: 450 }}
      >
        <div className="card-body py-2">
          <ul className="list-group list-group-flush">
            {state.sort().map((level1: any, index: number) => {
              return (
                level1 && (
                  <li key={`leaf-${level1}${index}`} className="list-group-item pr-0">
                    <div className="user-input" style={{ display: 'flex', alignItems: 'center' }}>
                      <span
                        className="stateKey"
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          flex: '1 0 60%',
                          whiteSpace: 'nowrap',
                          textOverflow: 'ellipsis',
                          overflow: 'hidden',
                        }}
                        title={level1.key}
                      >
                        {level1.key}
                      </span>
                      <AutoDetectInput
                        label={level1.key}
                        value={level1}
                        state={state}
                        onChange={handleValueChange}
                      />
                    </div>
                  </li>
                )
              );
            })}
          </ul>
        </div>
      </div>
    </div>
  ) : null;
};

export default CapiVariablePicker;
