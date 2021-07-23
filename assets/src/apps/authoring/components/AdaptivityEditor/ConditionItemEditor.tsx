import React, { Fragment, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
// import { Input, Select } from 'semantic-ui-react';

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

const ConditionItemEditor = (props: any) => {
  const { condition, onChange } = props;

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

  const handleOperatorChange = (e: any, data: any) => {
    const val = data.value;
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

  return (
    <div className="d-flex mt-1">
      <label className="sr-only" htmlFor="target">
        target
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
        id="target"
        defaultValue="0"
      >
        <option value="0">Choose...</option>
        <option value="1">One</option>
        <option value="2">Two</option>
        <option value="3">Three</option>
      </select>
      <label className="sr-only" htmlFor="type">
        type
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
        id="type"
        defaultValue="0"
      >
        <option value="0">Choose...</option>
        <option value="1">One</option>
        <option value="2">Two</option>
        <option value="3">Three</option>
      </select>
      <label className="sr-only" htmlFor="operator">
        operator
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm flex-grow-1 mw-25"
        id="operator"
        defaultValue="0"
      >
        <option value="0">
          Choose with a really long name that might stretch out the labeel?...
        </option>
        <option value="1">One</option>
        <option value="2">Two</option>
        <option value="3">Three</option>
      </select>
      <label className="sr-only">value</label>
      <input type="email" className="form-control form-control-sm flex-grow-1 mw-25" id="value" />
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
          <button className="btn btn-link p-0 ml-1">
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
    // <Fragment>
    //   <Input fluid placeholder="Fact" defaultValue={fact} onBlur={handleFactChange} />
    //   <Select
    //     options={conditionOperatorOptions}
    //     placeholder="Operator"
    //     defaultValue={operator}
    //     onChange={handleOperatorChange}
    //   />
    //   <Input fluid placeholder="Value" defaultValue={value} onBlur={handleValueChange} />
    // </Fragment>
  );
};

export default ConditionItemEditor;
