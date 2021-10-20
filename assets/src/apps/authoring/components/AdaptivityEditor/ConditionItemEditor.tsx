import { debounce } from 'lodash';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { CapiVariableTypes, getCapiType } from '../../../../adaptivity/capi';
import {
  ConditionOperatorOption,
  conditionOperatorOptions,
  ConditionTypeOperatorCombo,
  conditionTypeOperatorCombos,
  TypeOption,
  typeOptions,
} from './AdaptiveItemOptions';
import { JanusConditionProperties } from './ConditionsBlockEditor';
import { OverlayPlacements, VariablePicker } from './VariablePicker';

interface ConditionItemEditorProps {
  condition: JanusConditionProperties;
  parentIndex: number;
  onChange: (condition: Partial<JanusConditionProperties>) => void;
  onDelete: () => void;
}

const ConditionItemEditor: React.FC<ConditionItemEditorProps> = (props) => {
  const { condition, parentIndex, onChange, onDelete } = props;

  const [fact, setFact] = useState<string>(condition.fact);
  const [targetType, setTargetType] = useState<CapiVariableTypes>(
    condition.type || getCapiType(condition.value),
  );
  const [operator, setOperator] = useState<string>(condition.operator);
  const [value, setValue] = useState<any>(condition.value);

  const [workingCondition, setWorkingCondition] = useState<Partial<JanusConditionProperties>>({
    fact,
    type: targetType,
    operator,
    value,
  });

  const debouncedOnChange = useCallback(
    debounce((changes) => onChange(changes), 30),
    [onChange],
  );

  const notifyChanges = useCallback(() => {
    console.log('notifyChanges', { workingCondition });
    debouncedOnChange({
      fact: workingCondition.fact,
      type: workingCondition.type,
      operator: workingCondition.operator,
      value: workingCondition.value,
    });
  }, [workingCondition, debouncedOnChange]);

  useEffect(() => {
    const hasChanged =
      workingCondition.fact !== fact ||
      workingCondition.type !== targetType ||
      workingCondition.operator !== operator ||
      workingCondition.value !== value;
    if (hasChanged) {
      notifyChanges();
    }
  }, [workingCondition, fact, targetType, operator, value, notifyChanges]);

  const handleFactChange = useCallback(
    (e: any) => {
      const val = e.target.value;
      if (val === fact) {
        return;
      }
      setFact(val);
      setWorkingCondition((current) => ({ ...current, fact: val }));
    },
    [fact],
  );

  const handleTargetTypeChange = useCallback(
    (e: any) => {
      const val = parseInt(e.target.value);
      if (val === targetType) {
        return;
      }
      setTargetType(val);
      setWorkingCondition((current) => ({ ...current, type: val }));
    },
    [targetType],
  );

  const handleOperatorChange = useCallback(
    (e: any) => {
      const val = e.target.value;
      if (val === operator) {
        return;
      }
      setOperator(val);
      setWorkingCondition((current) => ({ ...current, operator: val }));
    },
    [operator],
  );

  const handleValueChange = useCallback(
    (e: any) => {
      const val = e.target.value;
      if (val === value) {
        return;
      }
      setValue(val);
      setWorkingCondition((current) => ({ ...current, value: val }));
    },
    [value],
  );

  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);

  const getFilteredConditionOperatorOptions = useCallback((): ConditionOperatorOption[] => {
    const filteredConditionOperatorOptions: ConditionOperatorOption[] = [];
    const filteredCombo: ConditionTypeOperatorCombo[] = conditionTypeOperatorCombos.filter(
      (combo) => combo.type === targetType,
    );
    filteredCombo[0].operators.forEach((comboOperator) => {
      conditionOperatorOptions.forEach((conditionOperator) => {
        if (conditionOperator.key === comboOperator) {
          filteredConditionOperatorOptions.push(conditionOperator);
        }
      });
    });
    return filteredConditionOperatorOptions;
  }, [targetType]);

  useEffect(() => {
    // when the targetType is manually changed, we may need to also set the operator
    setTimeout(() => {
      const operatorOptions = getFilteredConditionOperatorOptions();
      const validOperator = operatorOptions.find((option) => option.value === operator);
      const updatedOperator = validOperator?.value || operatorOptions[0].value;
      if (updatedOperator === operator) {
        return;
      }
      setOperator(updatedOperator);
      setWorkingCondition((current) => ({ ...current, operator: updatedOperator }));
    }, 10);
  }, [targetType, operator]);

  return (
    <div key={parentIndex} className="d-flex mt-1">
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Target">
          <VariablePicker
            targetRef={targetRef}
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
          className="form-control form-control-sm flex-grow-1 mr-2"
          type="text"
          placeholder="Target"
          defaultValue={fact}
          onBlur={(e) => handleFactChange(e)}
          title={fact}
          tabIndex={0}
          ref={targetRef}
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
        title={operator}
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
        onBlur={(e) => handleValueChange(e)}
        title={value}
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
          <button className="btn btn-link p-0 ml-1" onClick={() => onDelete()}>
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
  );
};

export default ConditionItemEditor;
