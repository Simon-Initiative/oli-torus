/* eslint-disable react/react-in-jsx-scope */
import { useEffect, useState } from 'react';
import { CapiVariable } from 'adaptivity/capi';
import { ApplyStateOperation } from 'adaptivity/scripting';
import NestedStateDisplay from 'apps/delivery/components/preview-tools/inspector/NestedStateDisplay';
import { hasNesting, unflatten } from 'apps/delivery/components/preview-tools/inspector/utils';
import AutoDetectInput from '../../../../src/apps/delivery/components/preview-tools/inspector/AutoDetectInput';
import './CapiVariablePicker.scss';

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
  const [expandedPanels, setExpandedPanels]: any = useState({});
  const [stageState, setStageState] = useState<any>({});
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
  useEffect(() => {
    setExpandedPanels({
      [`panel-Root${label}`]: true,
    });
  }, []);
  useEffect(() => {
    const globalStateAsVars = state.reduce((collect: any, capiState: any) => {
      const { key, value, allowedValues, bindTo, writeonly, type, readonly } = capiState;
      collect[key] = new CapiVariable({
        key,
        value,
        allowedValues,
        bindTo,
        writeonly,
        type,
        readonly,
      });
      return collect;
    }, {});
    const stageSlice: any = unflatten(globalStateAsVars);
    return setStageState(stageSlice);
  }, [state]);
  return state.length > 0 ? (
    <>
      <div>
        {showSaveCancelButtons && (
          <div
            className="apply-changes btn-group-sm
          p-2"
            role="group"
            aria-label="Apply changes"
          >
            <button type="button" className="btn btn-secondary mr-1" onClick={handleCancelChanges}>
              Cancel
            </button>
            <button type="button" className="btn btn-primary ml-1" onClick={handleApplyChanges}>
              Save
            </button>
          </div>
        )}
      </div>
      <div id="CAPIVariablePicker">
        <div className="pt-body">
          <div className="inspector">
            <div className="accordion">
              <div className="card even">
                <div className="card-header" id={`headingRoot${label}`}>
                  <h4 className="mb-0">
                    <button
                      className="btn btn-link text-left"
                      type="button"
                      aria-expanded={expandedPanels[`panel-Root${label}`]}
                      aria-controls={`collapseRoot${label}`}
                      onClick={() => {
                        setExpandedPanels({
                          [`panel-Root${label}`]: !expandedPanels[`panel-Root${label}`],
                        });
                      }}
                    >
                      <span
                        className={`chevron-arrow mr-2${
                          expandedPanels[`panel-Root${label}`] ? ' rotate' : ''
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
                      {label}
                    </button>
                  </h4>
                </div>
                <div
                  id={`collapseRoot${label}`}
                  className={`${expandedPanels[`panel-Root${label}`] ? '' : 'visually-hidden'}`}
                  aria-labelledby={`headingRoot${label}`}
                >
                  <div className="card-body">
                    <ul className="list-group list-group-flush">
                      {Object.keys(stageState)
                        .sort()
                        .map((level1: any, index: number) =>
                          !hasNesting(stageState[level1]) ? (
                            <li key={`leaf-${level1}${index}`} className="list-group-item pr-0">
                              <div className="user-input">
                                <span className="stateKey" title={level1}>
                                  {level1}
                                </span>
                                <AutoDetectInput
                                  label={level1}
                                  value={stageState[level1]}
                                  state={stageState}
                                  onChange={handleValueChange}
                                />
                              </div>
                            </li>
                          ) : (
                            <NestedStateDisplay
                              key={`${level1}${index}`}
                              rootLevel={level1}
                              levelIndex={1}
                              state={stageState}
                              onChange={handleValueChange}
                            />
                          ),
                        )}
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  ) : null;
};

export default CapiVariablePicker;
