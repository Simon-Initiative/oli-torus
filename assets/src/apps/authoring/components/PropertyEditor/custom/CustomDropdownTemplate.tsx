import React, { Fragment, useState } from 'react';
import { SequenceDropdown } from './SequenceDropdown';
import { getHierarchy } from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';

interface CustomDropdownProps {
  label: string
  uiSchema: any;
  description: string;
  properties: any;
  value: string;
}
const CustomDropdownTemplate: React.FC<CustomDropdownProps> = (props) => {
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);

  const onChangeHandler = () => {

  }
  return (
    <Fragment>
      <span  className="form-label">{props.label}</span>
      <SequenceDropdown items={hierarchy} onChange={onChangeHandler} value={props.value} />
    </Fragment>
  );
};

export default CustomDropdownTemplate;
