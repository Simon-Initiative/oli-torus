import React, { useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import { CapiVariableTypes, JanusConditionProperties } from '../../../../adaptivity/capi';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import {
  ConditionOperatorOption,
  ConditionTypeOperatorCombo,
  TypeOption,
  conditionOperatorOptions,
  conditionTypeOperatorCombos,
  inferTypeFromOperatorAndValue,
  typeOptions,
} from './AdaptiveItemOptions';
import { OverlayPlacements, VariablePicker } from './VariablePicker';

interface ConditionItemEditorProps {
  condition: JanusConditionProperties;
  parentIndex: number;
  onChange: (condition: Partial<JanusConditionProperties>) => void;
  onDelete: () => void;
}

const ConditionItemEditor: React.FC<ConditionItemEditorProps> = (props) => {
  const { condition, parentIndex, onChange, onDelete } = props;
  const dispatch = useDispatch();
  const [fact, setFact] = useState<string>(condition.fact);
  const [targetType, setTargetType] = useState<CapiVariableTypes>(
    condition.type || inferTypeFromOperatorAndValue(condition.operator, condition.value),
  );
  const [operator, setOperator] = useState<string>(condition.operator);
  const [value, setValue] = useState<any>(condition.value);
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);

  const handleFactChange = (val: any) => {
    setFact(val);
    onChange({ fact: val });
  };

  const handleTargetTypeChange = (e: any) => {
    const val = parseInt(e.target.value);
    if (val === targetType) {
      return;
    }
    setTargetType(val);
    onChange({ type: val });
  };

  const handleOperatorChange = (e: any) => {
    const val = e.target.value;
    if (val === operator) {
      return;
    }
    setOperator(val);
    onChange({ operator: val });
  };

  const handleValueChange = (e: any) => {
    const val = e.target.value;
    if (val === value) {
      return;
    }
    setValue(val);
    onChange({ value: val });
  };

  const typeRef = useRef<HTMLSelectElement>(null);

  const getFilteredConditionOperatorOptions = (): ConditionOperatorOption[] => {
    const filteredConditionOperatorOptions: ConditionOperatorOption[] = [];
    const filteredCombo: ConditionTypeOperatorCombo[] = conditionTypeOperatorCombos.filter(
      (combo) => combo.type === targetType,
    );
    filteredCombo[0]?.operators.forEach((comboOperator) => {
      conditionOperatorOptions.forEach((conditionOperator) => {
        if (conditionOperator.key === comboOperator) {
          filteredConditionOperatorOptions.push(conditionOperator);
        }
      });
    });
    return filteredConditionOperatorOptions;
  };

  useEffect(() => {
    // when the targetType is manually changed, we may need to also set the operator
    setTimeout(() => {
      const filteredOperations = getFilteredConditionOperatorOptions();
      const operatorInList = filteredOperations.find((option) => option.value === operator);
      const updatedOperator = operatorInList ? operatorInList.value : filteredOperations[0].value;
      if (updatedOperator === operator) {
        return;
      }
      setOperator(updatedOperator);
      onChange({ operator: updatedOperator });
    }, 10);
  }, [targetType]);

  React.useEffect(() => {
    setFact(condition.fact);
  }, [condition.fact]);

  return (
    <div key={parentIndex} className="d-flex mt-1">
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Target">
          <VariablePicker
            onTargetChange={(value) => handleFactChange(value)}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
            context="condition"
          />
        </div>
        <label className="sr-only" htmlFor={`target-${parentIndex}`}>
          target
        </label>
        <input
          key={`target-${parentIndex}`}
          id={`target-${parentIndex}`}
          className="form-control form-control-sm flex-grow-1 mr-2 w-8"
          type="text"
          placeholder="Target"
          value={fact}
          onChange={(e) => setFact(e.target.value)}
          onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
          onBlur={(e) => {
            handleFactChange(e.target.value);
            dispatch(setCurrentPartPropertyFocus({ focus: true }));
          }}
          title={fact?.toString() || ''}
          tabIndex={0}
        />
      </div>
      <label className="sr-only" htmlFor={`target-type-${parentIndex}`}>
        type
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm"
        id={`target-type-${parentIndex}`}
        defaultValue={targetType}
        onChange={(e) => handleTargetTypeChange(e)}
        ref={typeRef}
      >
        {typeOptions.map((type: TypeOption) => (
          <option key={type.key} value={type.value}>
            {type.text}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`operator-${parentIndex}`}>
        operator
      </label>
      <select
        key={`operator-${parentIndex}`}
        className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
        id={`operator-${parentIndex}`}
        placeholder="Operator"
        defaultValue={operator}
        onChange={(e) => handleOperatorChange(e)}
        title={operator?.toString() || ''}
        tabIndex={0}
      >
        {getFilteredConditionOperatorOptions().map(
          (option: ConditionOperatorOption, index: number) => (
            <option key={`option${index}-${parentIndex}`} value={option.value} title={option.key}>
              {option.text}
            </option>
          ),
        )}
      </select>
      <label className="sr-only" htmlFor={`value-${parentIndex}`}>
        value
      </label>
      <input
        type="text"
        className="form-control form-control-sm flex-grow-1 mw-25"
        key={`value-${parentIndex}`}
        id={`value-${parentIndex}`}
        defaultValue={value}
        onBlur={(e) => {
          handleValueChange(e);
          dispatch(setCurrentPartPropertyFocus({ focus: true }));
        }}
        onFocus={(e) => dispatch(setCurrentPartPropertyFocus({ focus: false }))}
        title={value?.toString() || ''}
        placeholder="Value"
        tabIndex={0}
      />
      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete Condition
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
          elementType="Condition"
          elementName="this rule condition"
          deleteHandler={() => {
            onDelete();
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

export default ConditionItemEditor;
