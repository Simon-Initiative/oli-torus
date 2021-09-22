import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import debounce from 'lodash/debounce';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { getIsBank, getIsLayer } from '../../../delivery/store/features/groups/actions/sequence';
import { OverlayPlacements, VariablePicker } from './VariablePicker';
import { CapiVariableTypes } from '../../../../adaptivity/capi';

export interface InitStateEditorProps {
  content?: Record<string, unknown>;
}

export interface InitialState {
  id: string;
  operator: string;
  target: string;
  type: number;
  value: string;
}

interface InitStateItemProps {
  state: InitialState;
  onChange: (id: string, key: string, value: string) => void;
  onDelete: (id: string) => void;
}
const InitStateItem: React.FC<InitStateItemProps> = ({ state, onChange, onDelete }) => {
  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);

  // update adding operator if targetType changes from number
  useEffect(() => {
    if (state.type !== 1) {
      if (state.operator === 'adding') {
        onChange(state.id, 'operator', '=');
      }
    }
  }, [state.type]);

  return (
    <div
      key={state.id}
      className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap"
    >
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Target">
          <VariablePicker
            targetRef={targetRef}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="init"
          />
        </div>
        <label className="sr-only" htmlFor={`target-${state.id}`}>
          target
        </label>
        <input
          key={`target-${state.id}`}
          id={`target-${state.id}`}
          className="form-control form-control-sm flex-grow-1 mr-2"
          type="text"
          placeholder="Target"
          defaultValue={state.target}
          onBlur={(e) => onChange(state.id, 'target', e.target.value)}
          title={state.target}
          tabIndex={0}
          ref={targetRef}
        />
      </div>

      <label className="sr-only" htmlFor={`operator-${state.id}`}>
        operator
      </label>
      <select
        key={`type-${state.id}`}
        className="custom-select mr-2 form-control form-control-sm"
        id={`type-${state.id}`}
        value={state.type}
        onChange={(e) => onChange(state.id, 'type', e.target.value)}
        title="Type"
        tabIndex={0}
        ref={typeRef}
      >
        {typeOptions.map((option: TypeOption, index: number) => (
          <option key={`option${index}-${state.id}`} value={option.value}>
            {option.text}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`operator-${state.id}`}>
        operator
      </label>
      <select
        key={`operator-${state.id}`}
        className="custom-select mr-2 form-control form-control-sm"
        id={`operator-${state.id}`}
        value={state.operator}
        onChange={(e) => onChange(state.id, 'operator', e.target.value)}
        title="Operator"
        tabIndex={0}
      >
        {opOptions.map((option: OperatorOption, index: number) => (
          <option
            key={`option${index}-${state.id}`}
            value={option.value}
            style={state.type !== 1 && option.key === 'add' ? { display: 'none' } : undefined}
          >
            {option.text}
          </option>
        ))}
      </select>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Value">
          <div className="input-group-text">
            <i className="fa fa-flag-checkered" />
          </div>
        </div>
        <label className="sr-only" htmlFor={`value-${state.id}`}>
          value
        </label>
        <input
          type="text"
          className="form-control form-control-sm flex-grow-1"
          key={`value-${state.id}`}
          id={`value-${state.id}`}
          defaultValue={state.value}
          placeholder="Value"
          onBlur={(e) => onChange(state.id, 'value', e.target.value)}
          title={state.value}
          tabIndex={0}
        />
      </div>
      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete State
          </Tooltip>
        }
      >
        <span>
          <button className="btn btn-link p-0 ml-1" onClick={() => onDelete(state.id)}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
  );
};

interface TypeOption {
  key: string;
  text: string;
  value: number;
}
const typeOptions: TypeOption[] = [
  { key: 'string', text: 'String', value: CapiVariableTypes.STRING },
  { key: 'number', text: 'Number', value: CapiVariableTypes.NUMBER },
  { key: 'array', text: 'Array', value: CapiVariableTypes.ARRAY },
  { key: 'boolean', text: 'Boolean', value: CapiVariableTypes.BOOLEAN },
  { key: 'enum', text: 'Enum', value: CapiVariableTypes.ENUM },
  { key: 'math', text: 'Math Expression', value: CapiVariableTypes.MATH_EXPR },
  { key: 'parray', text: 'Point Array', value: CapiVariableTypes.ARRAY_POINT },
];

interface OperatorOption {
  key: string;
  text: string;
  value: string;
}
const opOptions: OperatorOption[] = [
  { key: 'equal', text: '=', value: '=' },
  { key: 'add', text: 'Adding', value: 'adding' },
  { key: 'bind', text: 'Bind To', value: 'bind to' },
  { key: 'set', text: 'Setting To', value: 'setting to' },
];

export const InitStateEditor: React.FC<InitStateEditorProps> = () => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const [initState, setInitState] = useState([]);
  const [isDirty, setIsDirty] = useState(false);
  const isLayer = getIsLayer();
  const isBank = getIsBank();

  useEffect(() => {
    if (currentActivity === undefined) return;
    setInitState(currentActivity?.content?.custom?.facts);
  }, [currentActivity]);

  useEffect(() => {
    if (!isDirty) {
      return;
    }
    const activityClone = clone(currentActivity);
    const initStateClone = clone(initState);
    activityClone.content.custom.facts = initStateClone;
    dispatch(saveActivity({ activity: activityClone }));
    setIsDirty(false);
  }, [isDirty]);

  const notifyTime = 250;
  const debounceSaveChanges = useCallback(
    debounce(
      () => {
        setIsDirty(true);
      },
      notifyTime,
      { leading: false },
    ),
    [],
  );

  const handleAdd = () => {
    const tempRules = clone(initState);
    const tempRule = {
      id: `is:${guid()}`,
      target: '',
      value: '',
      type: typeOptions[0].value,
      operator: opOptions[0].value,
    };
    tempRules.push(tempRule);
    setInitState(tempRules);
  };

  const handleDelete = (id: string) => {
    const initStateClone = clone(initState);
    const indexToDelete = initStateClone.findIndex((rule: InitialState) => rule.id === id);
    initStateClone.splice(indexToDelete, 1);
    setInitState(initStateClone);
    debounceSaveChanges();
  };

  const handleChange = (id: string, key: string, value: string) => {
    if (value.trim() === '') return;
    const initStateClone = clone(initState);
    const indexToUpdate = initStateClone.findIndex((rule: InitialState) => rule.id === id);
    if (initStateClone[indexToUpdate][key] === value) return;
    if (key == 'type') {
      initStateClone[indexToUpdate][key] = parseInt(value);
    } else {
      initStateClone[indexToUpdate][key] = value;
    }
    setInitState(initStateClone);
    debounceSaveChanges();
  };

  return (
    <div className="aa-initState-editor">
      {(isLayer || isBank) && (
        <div className="text-center border rounded">
          <div className="card-body">
            {`This sequence item is a ${
              isLayer ? 'layer' : 'question bank'
            } and does not support adaptivity`}
          </div>
        </div>
      )}
      {!isLayer && !isBank && (
        <div className="d-flex w-100">
          <OverlayTrigger
            placement="top"
            delay={{ show: 150, hide: 150 }}
            overlay={
              <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                New State
              </Tooltip>
            }
          >
            <button
              className="aa-add-button btn btn-primary btn-sm mr-3"
              type="button"
              onClick={() => handleAdd()}
            >
              <i className="fa fa-plus" />
            </button>
          </OverlayTrigger>
          {initState.length === 0 && (
            <div className="d-flex flex-column w-100 border rounded p-2">
              <div className="text-center">Initial State is currently empty.</div>
            </div>
          )}
          {initState.length > 0 && (
            <div className="w-100">
              {initState.map((state: InitialState, index: number) => (
                <InitStateItem
                  key={index}
                  state={state}
                  onChange={handleChange}
                  onDelete={handleDelete}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
