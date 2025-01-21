import React, { useCallback, useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import debounce from 'lodash/debounce';
import flatten from 'lodash/flatten';
import uniq from 'lodash/uniq';
import { getReferencedKeysInConditions } from 'adaptivity/rules-engine';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import { CapiVariableTypes } from '../../../../adaptivity/capi';
import { saveActivity } from '../../../authoring/store/activities/actions/saveActivity';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { getIsBank, getIsLayer } from '../../../delivery/store/features/groups/actions/sequence';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import {
  ActionOperatorOption,
  TypeOption,
  actionOperatorOptions,
  typeOptions,
} from './AdaptiveItemOptions';
import { OverlayPlacements, VariablePicker } from './VariablePicker';

export interface InitStateEditorProps {
  content?: Record<string, unknown>;
  authoringContainer: React.RefObject<HTMLElement>;
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
  authoringContainer: React.RefObject<HTMLElement>;
  onChange: (id: string, key: string, value: string) => void;
  onDelete: (id: string) => void;
}
const InitStateItem: React.FC<InitStateItemProps> = ({ state, onChange, onDelete }) => {
  const typeRef = useRef<HTMLSelectElement>(null);
  const dispatch = useDispatch();
  const [target, setTarget] = useState(state.target);
  const [value, setValue] = useState(state.value);

  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  const handleTargetChange = (val: any) => {
    setTarget(val);
    onChange(state.id, 'target', val);
  };

  // update adding operator if targetType changes from number
  useEffect(() => {
    if (state.type !== CapiVariableTypes.NUMBER) {
      if (state.operator === 'adding') {
        onChange(state.id, 'operator', '=');
      }
    }
  }, [state.type]);

  React.useEffect(() => {
    setTarget(state.target);
  }, [state.target]);

  React.useEffect(() => {
    setValue(state.value);
  }, [state.value]);

  return (
    <div
      key={state.id}
      className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap"
    >
      <div className="input-group input-group-sm flex-grow-1 flex-shrink-0">
        <div className="input-group-prepend" title="Target">
          <VariablePicker
            onTargetChange={(value) => handleTargetChange(value)}
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
          className="form-control form-control-sm flex-grow-1 mr-2 w-40"
          type="text"
          placeholder="Target"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
          onBlur={(e) => {
            handleTargetChange(e.target.value);
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          title={target.toString()}
          tabIndex={0}
        />
      </div>

      <label className="sr-only" htmlFor={`operator-${state.id}`}>
        type
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
        {actionOperatorOptions
          .filter((option: ActionOperatorOption) => {
            if (state.type !== CapiVariableTypes.NUMBER) {
              return option.key !== 'add';
            }
            return true;
          })
          .map((option: ActionOperatorOption, index: number) => (
            <option key={`option${index}-${state.id}`} value={option.value}>
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
          className="form-control flex-grow-1"
          key={`value-${state.id}`}
          id={`value-${state.id}`}
          value={value}
          placeholder="Value"
          onChange={(e) => setValue(e.target.value)}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
          onBlur={(e) => {
            onChange(state.id, 'value', e.target.value);
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          title={state.value.toString()}
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
          <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Initial State"
          elementName="this initial state rule"
          deleteHandler={() => {
            onDelete(state.id);
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

export const InitStateEditor: React.FC<InitStateEditorProps> = ({ authoringContainer }) => {
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
    const conditionWithExpression = [];
    conditionWithExpression.push(...getReferencedKeysInConditions(initStateClone, true));

    if (!activityClone.content.custom.conditionsRequiredEvaluation) {
      activityClone.content.custom.conditionsRequiredEvaluation = [];
    }
    activityClone.content.custom.conditionsRequiredEvaluation.push(conditionWithExpression);
    activityClone.content.custom.conditionsRequiredEvaluation = uniq(
      flatten([...new Set(activityClone.content.custom.conditionsRequiredEvaluation)]),
    );
    dispatch(saveActivity({ activity: activityClone, undoable: true, immediate: true }));
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
      target: 'stage.',
      value: '',
      type: typeOptions[0].value,
      operator: actionOperatorOptions[0].value,
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
        <div className="d-flex">
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
            <div className="d-flex flex-column border rounded p-2 flex-1">
              <div className="text-center">Initial State is currently empty.</div>
            </div>
          )}
          {initState.length > 0 && (
            <div className="flex-1">
              {initState.map((state: InitialState, index: number) => (
                <InitStateItem
                  key={index}
                  state={state}
                  onChange={handleChange}
                  onDelete={handleDelete}
                  authoringContainer={authoringContainer}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
