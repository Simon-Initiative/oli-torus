import React, { useEffect, useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';

const typeOptions = [
  { key: 'number', text: 'Number', value: 1 },
  { key: 'string', text: 'String', value: 2 },
  { key: 'array', text: 'Array', value: 3 },
  { key: 'boolean', text: 'Boolean', value: 4 },
  { key: 'enum', text: 'Enum', value: 5 },
  { key: 'math', text: 'Math Expression', value: 6 },
  { key: 'parray', text: 'Point Array', value: 7 },
];
const opOptions = [
  { key: 'add', text: 'Adding', value: 'adding' },
  { key: 'bind', text: 'Bind To', value: 'bind to' },
  { key: 'set', text: 'Setting To', value: 'setting to' },
  { key: 'equal', text: '=', value: '=' },
];

const ActionMutateEditor = (props: any) => {
  const { action, onChange } = props;

  const [target, setTarget] = useState(action.params.target);
  const [targetType, setTargetType] = useState(action.params.targetType);
  const [operator, setOperator] = useState(action.params.operator);
  const [value, setValue] = useState(action.params.value);
  const [isDirty, setIsDirty] = useState(false);
  const uuid = guid();

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

  return (
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-mutate-target-${uuid}`}>
        target
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="target">
          <div className="input-group-text">
            <i className="fa fa-crosshairs" />
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm mr-2 w-25"
          id={`action-mutate-target-${uuid}`}
          value={target}
          onChange={(e) => handleTargetChange(e)}
          title={target}
        />
      </div>
      <label className="sr-only" htmlFor={`action-mutate-type-${uuid}`}>
        type
      </label>
      <select
        className="custom-select mr-2 form-control form-control-sm w-25"
        id={`action-mutate-type-${uuid}`}
        defaultValue={targetType}
        onChange={(e) => handleTargetTypeChange(e)}
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
        className="custom-select mr-2 form-control form-control-sm w-25"
        id={`action-mutate-operator-${uuid}`}
        defaultValue={operator}
        onChange={(e) => handleOperatorChange(e)}
      >
        {opOptions.map((option) => (
          <option key={option.key} value={option.value}>
            {option.text}
          </option>
        ))}
      </select>
      <label className="sr-only" htmlFor={`action-mutate-value-${uuid}`}>
        value
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend" title="value">
          <div className="input-group-text">
            <i className="fa fa-flag-checkered" />
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm w-25"
          id={`action-mutate-value-${uuid}`}
          value={value}
          onChange={(e) => handleValueChange(e)}
          title={value}
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
          <button className="btn btn-link p-0 ml-1">
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>

    // <Fragment>
    //   <Icon name="edit" size="large" />
    //   <List.Content>
    //     Change State:
    //     <Input fluid placeholder="Target" defaultValue={target} onBlur={handleTargetChange} />
    //     <Select options={typeOptions} defaultValue={targetType} onChange={handleTargetTypeChange} />
    //     <Select
    //       options={opOptions}
    //       placeholder="Operator"
    //       defaultValue={operator}
    //       onChange={handleOperatorChange}
    //     />
    //     <Input fluid placeholder="Value" defaultValue={value} onBlur={handleValueChange} />
    //   </List.Content>
    // </Fragment>
  );
};

export default ActionMutateEditor;
