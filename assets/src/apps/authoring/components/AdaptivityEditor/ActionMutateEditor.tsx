import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { MutateStateAction, MutateStateActionParams } from 'apps/authoring/types';
import React, { useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';
import { VariablePicker, OverlayPlacements } from './VariablePicker';

const typeOptions = [
  { key: 'string', text: 'String', value: CapiVariableTypes.STRING },
  { key: 'number', text: 'Number', value: CapiVariableTypes.NUMBER },
  { key: 'array', text: 'Array', value: CapiVariableTypes.ARRAY },
  { key: 'boolean', text: 'Boolean', value: CapiVariableTypes.BOOLEAN },
  { key: 'enum', text: 'Enum', value: CapiVariableTypes.ENUM },
  { key: 'math', text: 'Math Expression', value: CapiVariableTypes.MATH_EXPR },
  { key: 'parray', text: 'Point Array', value: CapiVariableTypes.ARRAY_POINT },
];
const opOptions = [
  { key: 'equal', text: '=', value: '=' },
  { key: 'add', text: 'Adding', value: 'adding' },
  { key: 'bind', text: 'Bind To', value: 'bind to' },
  { key: 'set', text: 'Setting To', value: 'setting to' },
];

interface ActionMutateEditorProps {
  action: MutateStateAction;
  onChange: (changes: MutateStateActionParams) => void;
  onDelete: (changes: MutateStateAction) => void;
}

const ActionMutateEditor: React.FC<ActionMutateEditorProps> = (props) => {
  const { action, onChange, onDelete } = props;

  const [target, setTarget] = useState(action.params.target);
  const [targetType, setTargetType] = useState(action.params.targetType);
  const [operator, setOperator] = useState(action.params.operator);
  const [value, setValue] = useState(action.params.value);
  const [isDirty, setIsDirty] = useState(false);
  const uuid = guid();

  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);

  const handleTargetChange = (e: any) => {
    const val = e.target.value;
    if (val === target) {
      // since using blur, don't need to update if there is no change
      return;
    }
    setTarget(val);
    setIsDirty(true);
  };

  const handleValueChange = (e: any) => {
    const val = e.target.value;
    if (val === value) {
      return;
    }
    setValue(val);
    setIsDirty(true);
  };

  const handleTargetTypeChange = (e: any) => {
    const val = e.target.value;
    if (val === targetType) {
      return;
    }
    setTargetType(val);
    setIsDirty(true);
  };

  const handleOperatorChange = (e: any) => {
    const val = e.target.value;
    if (val === operator) {
      return;
    }
    setOperator(val);
    setIsDirty(true);
  };

  const postChanges = () => {
    const val = {
      target,
      targetType,
      operator,
      value,
    };
    onChange(val);
    setIsDirty(false);
  };

  useEffect(() => {
    if (isDirty) {
      postChanges();
    }
  }, [isDirty]);

  // update adding operator if targetType changes from number
  useEffect(() => {
    if (targetType !== CapiVariableTypes.NUMBER) {
      if (operator === 'adding') {
        setTimeout(() => {
          setOperator('=');
          setIsDirty(true);
        });
      }
    }
  }, [targetType]);

  return (
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-mutate-target-${uuid}`}>
        target
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="target">
          <VariablePicker
            targetRef={targetRef}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="mutate"
          />
        </div>
        <input
          type="text"
          className="form-control form-control-sm mr-2 flex-grow-1"
          id={`action-mutate-target-${uuid}`}
          defaultValue={target}
          onBlur={(e) => handleTargetChange(e)}
          title={target}
          placeholder="Target"
          ref={targetRef}
        />
      </div>
      <label className="sr-only" htmlFor={`action-mutate-type-${uuid}`}>
        type
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm"
        id={`action-mutate-type-${uuid}`}
        value={targetType}
        onChange={(e) => handleTargetTypeChange(e)}
        ref={typeRef}
      >
        {typeOptions.map((type) => (
          <option key={type.key} value={type.value}>
            {type.text}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`action-mutate-operator-${uuid}`}>
        operator
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm"
        id={`action-mutate-operator-${uuid}`}
        value={operator}
        onChange={(e) => handleOperatorChange(e)}
      >
        {opOptions
          .filter((option) => {
            if (parseInt(targetType.toString(), 10) !== CapiVariableTypes.NUMBER) {
              return option.key !== 'add';
            }
            return true;
          })
          .map((option) => (
            <option key={option.key} value={option.value}>
              {option.text}
            </option>
          ))}
      </select>
      <label className="sr-only" htmlFor={`action-mutate-value-${uuid}`}>
        value
      </label>
      <div className="input-group input-group-sm">
        <div className="input-group-prepend" title="value">
          <div className="input-group-text">
            <i className="fa fa-flag-checkered" />
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm"
          id={`action-mutate-value-${uuid}`}
          value={value}
          onChange={(e) => handleValueChange(e)}
          title={value}
          placeholder="Value"
        />
      </div>

      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete Action
          </Tooltip>
        }
      >
        <span>
          <button className="btn btn-link p-0 ml-1" onClick={() => onDelete(action)}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
  );
};

export default ActionMutateEditor;
