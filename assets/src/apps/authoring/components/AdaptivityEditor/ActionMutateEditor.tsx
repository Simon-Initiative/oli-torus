import React, { Fragment, useEffect, useState } from 'react';
// import { Icon, List, Input, Select } from 'semantic-ui-react';

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

  const handleTargetTypeChange = (e: any, data: any) => {
    /* console.log('TT change', { e, data }); */
    const val = data.value;
    if (val === targetType) {
      return;
    }
    setTargetType(val);
    setIsDirty(true);
  };

  const handleOperatorChange = (e: any, data: any) => {
    const val = data.value;
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
    <div>ActionMutateEditor coming soon</div>
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
