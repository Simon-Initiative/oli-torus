import React, { useRef, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import state from 'state';
import guid from 'utils/guid';
import { JanusConditionProperties } from './ConditionsBlockEditor';
import { VariablePicker, OverlayPlacements } from './VariablePicker';

const conditionOperatorOptions = [
  { key: 'equal', text: '=', value: 'equal' },
  { key: 'lessThan', text: '<', value: 'lessThan' },
  { key: 'lessThanInclusive', text: '<=', value: 'equlessThanInclusiveal' },
  { key: 'notEqual', text: '!=', value: 'notEqual' },
  { key: 'greaterThan', text: '>', value: 'greaterThan' },
  { key: 'greaterThanInclusive', text: '>=', value: 'greaterThanInclusive' },
  { key: 'in', text: 'In', value: 'in' },
  { key: 'notIn', text: 'Not In', value: 'notIn' },
  { key: 'contains', text: 'Contains', value: 'contains' },
  { key: 'notContains', text: 'Not Contains', value: 'notContains' },
  { key: 'containsAnyOf', text: 'Contains Any', value: 'containsAnyOf' },
  {
    key: 'notContainsAnyOf',
    text: 'Not Contains Any',
    value: 'notContainsAnyOf',
  },
  { key: 'containsOnly', text: 'Contains Only', value: 'containsOnly' },
  { key: 'isAnyOf', text: 'Any Of', value: 'isAnyOf' },
  { key: 'notIsAnyOf', text: 'Not Any Of', value: 'notIsAnyOf' },
  { key: 'isNaN', text: 'Is NaN', value: 'isNaN' },
  { key: 'equalWithTolerance', text: '~==', value: 'equalWithTolerance' },
  {
    key: 'notEqualWithTolerance',
    text: '~!=',
    value: 'notEqualWithTolerance',
  },
  { key: 'inRange', text: 'In Range', value: 'inRange' },
  { key: 'notInRange', text: 'Not In Range', value: 'notInRange' },
  {
    key: 'containsExactly',
    text: 'Contains Exactly',
    value: 'containsExactly',
  },
  {
    key: 'notContainsExactly',
    text: 'Not Contains Exactly',
    value: 'notContainsExactly',
  },
  { key: 'endsWith', text: 'Ends With', value: 'endsWith' },
  { key: 'is', text: 'Is', value: 'is' },
  { key: 'notIs', text: 'Not Is', value: 'notIs' },
  { key: 'hasSameTerms', text: 'Has Same Terms', value: 'hasSameTerms' },
  { key: 'isEquivalentOf', text: 'Is Equivalent', value: 'isEquivalentOf' },
  { key: 'isExactly', text: 'Is Exactly', value: 'isExactly' },
  { key: 'notIsExactly', text: 'Not Is Exactly', value: 'notIsExactly' },
];

interface ConditionItemEditorProps {
  condition: JanusConditionProperties;
  onChange: (condition: Partial<JanusConditionProperties>) => void;
  onDelete: () => void;
}

const ConditionItemEditor: React.FC<ConditionItemEditorProps> = (props) => {
  const { condition, onChange, onDelete } = props;

  const [fact, setFact] = useState<string>(condition.fact);
  const [operator, setOperator] = useState<string>(condition.operator);
  const [value, setValue] = useState<any>(condition.value);

  const handleFactChange = (e: any) => {
    const val = e.target.value;
    if (val === fact) {
      return;
    }
    setFact(val);
    onChange({ fact: val });
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

  const uuid = guid();
  const targetRef = useRef<HTMLInputElement>(null);
  const typeRef = useRef<HTMLSelectElement>(null);
  return (
    <div className="d-flex mt-1">
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="Target">
          <VariablePicker
            targetRef={targetRef}
            typeRef={typeRef}
            placement={OverlayPlacements.TOP}
          />
        </div>
        <label className="sr-only" htmlFor={`target-${uuid}`}>
          target
        </label>
        <input
          key={`target-${uuid}`}
          id={`target-${uuid}`}
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
      <label className="sr-only" htmlFor={`operator-${uuid}`}>
        operator
      </label>
      <select
        key={`operator-${uuid}`}
        className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
        id={`operator-${uuid}`}
        placeholder="Operator"
        defaultValue={operator}
        onChange={(e) => handleOperatorChange(e)}
        title={operator}
        tabIndex={0}
      >
        {conditionOperatorOptions.map((option, index) => (
          <option key={`option${index}-${uuid}`} value={option.value} title={option.key}>
            {option.text}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`value-${uuid}`}>
        value
      </label>
      <input
        type="text"
        className="form-control form-control-sm flex-grow-1 mw-25"
        key={`value-${uuid}`}
        id={`value-${uuid}`}
        defaultValue={value}
        onBlur={(e) => handleValueChange(e)}
        title={value}
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
