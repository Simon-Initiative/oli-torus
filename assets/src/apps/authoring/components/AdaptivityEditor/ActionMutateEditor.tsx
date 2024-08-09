import React, { useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { MutateStateAction, MutateStateActionParams } from 'apps/authoring/types';
import guid from 'utils/guid';
import { CapiVariableTypes } from '../../../../adaptivity/capi';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import {
  ActionOperatorOption,
  TypeOption,
  actionOperatorOptions,
  typeOptions,
} from './AdaptiveItemOptions';
import { OverlayPlacements, VariablePicker } from './VariablePicker';

interface ActionMutateEditorProps {
  action: MutateStateAction;
  onChange: (changes: MutateStateActionParams) => void;
  onDelete: (changes: MutateStateAction) => void;
}

const ActionMutateEditor: React.FC<ActionMutateEditorProps> = (props) => {
  const { action, onChange, onDelete } = props;
  const dispatch = useDispatch();
  const [target, setTarget] = useState(action.params.target);
  const [targetType, setTargetType] = useState(action.params.targetType);
  const [operator, setOperator] = useState(action.params.operator);
  const [value, setValue] = useState(action.params.value);
  const [isDirty, setIsDirty] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const uuid = guid();

  const typeRef = useRef<HTMLSelectElement>(null);

  useEffect(() => setTarget(action.params.target), [action.params.target]);
  useEffect(() => setValue(action.params.value), [action.params.value]);

  const handleTargetChange = (val: any) => {
    setTarget(val);
    setIsDirty(true);
  };

  const handleValueChange = (e: any) => {
    const val = e.target.value;
    if (val === value) {
      return;
    }
    setValue(val);
  };

  const handleTargetTypeChange = (e: any) => {
    const val = parseInt(e.target.value);
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
            onTargetChange={(value) => handleTargetChange(value)}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="mutate"
          />
        </div>
        <input
          type="text"
          className="form-control form-control-sm mr-2 flex-grow-1 w-8"
          id={`action-mutate-target-${uuid}`}
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          onBlur={(e) => {
            handleTargetChange(e.target.value);
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
          title={target}
          placeholder="Target"
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
        {typeOptions.map((type: TypeOption) => (
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
        {actionOperatorOptions
          .filter((option: ActionOperatorOption) => {
            if (parseInt(targetType.toString(), 10) !== CapiVariableTypes.NUMBER) {
              return option.key !== 'add';
            }
            return true;
          })
          .map((option: ActionOperatorOption) => (
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
          className="form-control"
          id={`action-mutate-value-${uuid}`}
          value={value}
          onChange={(e) => handleValueChange(e)}
          onBlur={() => {
            setIsDirty(true);
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
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
          <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this mutate action"
          deleteHandler={() => {
            onDelete(action);
            setShowConfirmDelete(false);
          }}
          cancelHandler={() => {
            setShowConfirmDelete(false);
          }}
        />
      )}
    </div>
  );
};

export default ActionMutateEditor;
