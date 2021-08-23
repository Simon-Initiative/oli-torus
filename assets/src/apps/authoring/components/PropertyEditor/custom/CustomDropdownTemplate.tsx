import React, { Fragment, useState } from 'react';
import { SequenceDropdown } from './SequenceDropdown';
import {
  findInHierarchy,
  getHierarchy,
  SequenceEntryChild,
  SequenceHierarchyItem,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';
import { useEffect } from 'react';

interface CustomDropdownProps {
  id: string;
  label: string;
  uiSchema: any;
  description: string;
  properties: any;
  value: string;
  onChange: (value: string) => void;
}
const CustomDropdownTemplate: React.FC<CustomDropdownProps> = (props) => {
  const {id, label, uiSchema, description, properties, value, onChange } = props;
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const [buttonLabel, setButtonLabel] = useState<any>('');
  const [val, setVal] = useState<string>(value);
  useEffect(() => {
    const seq = findInHierarchy(hierarchy, val);
    setButtonLabel(seq?.custom.sequenceName);
  }, [val]);
  const onChangeHandler = (item: any) => {
    setVal(item.custom.sequenceId);
    onChange(item.custom.sequenceId);
  };
  return (
    <Fragment>
      <span className='form-label'>{label}</span>
      <div className='dropdown'>
        <button
          className='btn btn-secondary dropdown-toggle'
          type='button'
          id={id}
          data-toggle='dropdown'
          aria-haspopup='true'
          aria-expanded='false'
        >
          {buttonLabel}
        </button>
        <div className='dropdown-menu' aria-labelledby={id}>
          <SequenceDropdown items={hierarchy} onChange={onChangeHandler} value={props.value} />
        </div>
      </div>
    </Fragment>
  );
};

export default CustomDropdownTemplate;
