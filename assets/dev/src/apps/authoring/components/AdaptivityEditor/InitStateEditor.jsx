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
import { actionOperatorOptions, typeOptions, } from './AdaptiveItemOptions';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
const InitStateItem = ({ state, onChange, onDelete }) => {
    const targetRef = useRef(null);
    const typeRef = useRef(null);
    const [showConfirmDelete, setShowConfirmDelete] = useState(false);
    // update adding operator if targetType changes from number
    useEffect(() => {
        if (state.type !== CapiVariableTypes.NUMBER) {
            if (state.operator === 'adding') {
                onChange(state.id, 'operator', '=');
            }
        }
    }, [state.type]);
    return (<div key={state.id} className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Target">
          <VariablePicker targetRef={targetRef} typeRef={typeRef} placement={OverlayPlacements.TOP} context="init"/>
        </div>
        <label className="sr-only" htmlFor={`target-${state.id}`}>
          target
        </label>
        <input key={`target-${state.id}`} id={`target-${state.id}`} className="form-control form-control-sm flex-grow-1 mr-2" type="text" placeholder="Target" defaultValue={state.target} onBlur={(e) => onChange(state.id, 'target', e.target.value)} title={state.target} tabIndex={0} ref={targetRef}/>
      </div>

      <label className="sr-only" htmlFor={`operator-${state.id}`}>
        type
      </label>
      <select key={`type-${state.id}`} className="custom-select mr-2 form-control form-control-sm" id={`type-${state.id}`} value={state.type} onChange={(e) => onChange(state.id, 'type', e.target.value)} title="Type" tabIndex={0} ref={typeRef}>
        {typeOptions.map((option, index) => (<option key={`option${index}-${state.id}`} value={option.value}>
            {option.text}
          </option>))}
      </select>
      <label className="sr-only" htmlFor={`operator-${state.id}`}>
        operator
      </label>
      <select key={`operator-${state.id}`} className="custom-select mr-2 form-control form-control-sm" id={`operator-${state.id}`} value={state.operator} onChange={(e) => onChange(state.id, 'operator', e.target.value)} title="Operator" tabIndex={0}>
        {actionOperatorOptions
            .filter((option) => {
            if (state.type !== CapiVariableTypes.NUMBER) {
                return option.key !== 'add';
            }
            return true;
        })
            .map((option, index) => (<option key={`option${index}-${state.id}`} value={option.value}>
              {option.text}
            </option>))}
      </select>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Value">
          <div className="input-group-text">
            <i className="fa fa-flag-checkered"/>
          </div>
        </div>
        <label className="sr-only" htmlFor={`value-${state.id}`}>
          value
        </label>
        <input type="text" className="form-control form-control-sm flex-grow-1" key={`value-${state.id}`} id={`value-${state.id}`} defaultValue={state.value} placeholder="Value" onBlur={(e) => onChange(state.id, 'value', e.target.value)} title={state.value} tabIndex={0}/>
      </div>
      <OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete State
          </Tooltip>}>
        <span>
          <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
            <i className="fa fa-trash-alt"/>
          </button>
        </span>
      </OverlayTrigger>
      {showConfirmDelete && (<ConfirmDelete show={showConfirmDelete} elementType="Initial State" elementName="this initial state rule" deleteHandler={() => {
                onDelete(state.id);
                setShowConfirmDelete(false);
            }} cancelHandler={() => {
                setShowConfirmDelete(false);
            }}/>)}
    </div>);
};
export const InitStateEditor = () => {
    const dispatch = useDispatch();
    const currentActivity = useSelector(selectCurrentActivity);
    const [initState, setInitState] = useState([]);
    const [isDirty, setIsDirty] = useState(false);
    const isLayer = getIsLayer();
    const isBank = getIsBank();
    useEffect(() => {
        var _a, _b;
        if (currentActivity === undefined)
            return;
        setInitState((_b = (_a = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.content) === null || _a === void 0 ? void 0 : _a.custom) === null || _b === void 0 ? void 0 : _b.facts);
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
    const debounceSaveChanges = useCallback(debounce(() => {
        setIsDirty(true);
    }, notifyTime, { leading: false }), []);
    const handleAdd = () => {
        const tempRules = clone(initState);
        const tempRule = {
            id: `is:${guid()}`,
            target: 'stage.',
            value: '',
            type: typeOptions[0].value,
            operator: actionOperatorOptions[0].value,
        };
        tempRules.push(tempRule);
        setInitState(tempRules);
    };
    const handleDelete = (id) => {
        const initStateClone = clone(initState);
        const indexToDelete = initStateClone.findIndex((rule) => rule.id === id);
        initStateClone.splice(indexToDelete, 1);
        setInitState(initStateClone);
        debounceSaveChanges();
    };
    const handleChange = (id, key, value) => {
        if (value.trim() === '')
            return;
        const initStateClone = clone(initState);
        const indexToUpdate = initStateClone.findIndex((rule) => rule.id === id);
        if (initStateClone[indexToUpdate][key] === value)
            return;
        if (key == 'type') {
            initStateClone[indexToUpdate][key] = parseInt(value);
        }
        else {
            initStateClone[indexToUpdate][key] = value;
        }
        setInitState(initStateClone);
        debounceSaveChanges();
    };
    return (<div className="aa-initState-editor">
      {(isLayer || isBank) && (<div className="text-center border rounded">
          <div className="card-body">
            {`This sequence item is a ${isLayer ? 'layer' : 'question bank'} and does not support adaptivity`}
          </div>
        </div>)}
      {!isLayer && !isBank && (<div className="d-flex w-100">
          <OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                New State
              </Tooltip>}>
            <button className="aa-add-button btn btn-primary btn-sm mr-3" type="button" onClick={() => handleAdd()}>
              <i className="fa fa-plus"/>
            </button>
          </OverlayTrigger>
          {initState.length === 0 && (<div className="d-flex flex-column w-100 border rounded p-2">
              <div className="text-center">Initial State is currently empty.</div>
            </div>)}
          {initState.length > 0 && (<div className="w-100">
              {initState.map((state, index) => (<InitStateItem key={index} state={state} onChange={handleChange} onDelete={handleDelete}/>))}
            </div>)}
        </div>)}
    </div>);
};
//# sourceMappingURL=InitStateEditor.jsx.map