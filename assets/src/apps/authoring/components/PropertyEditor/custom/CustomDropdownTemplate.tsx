/* eslint-disable @typescript-eslint/ban-types */
import React, { Fragment, useState } from 'react';
import { SequenceDropdown } from './SequenceDropdown';
import {
  findInHierarchy,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';
import { useEffect } from 'react';

interface CustomDropdownProps {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
}
const CustomDropdownTemplate: React.FC<CustomDropdownProps> = (props) => {
  const { id, label, value, onChange } = props;
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const seq = findInHierarchy(hierarchy, value);
  const buttonLabel = seq?.custom.sequenceName;

  const onChangeHandler = (e: any, item: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    //setSelectedScreenId(item.custom.sequenceId);
    onChange(item.custom.sequenceId);
  };

  // useEffect(() => {
  //   const seq = findInHierarchy(hierarchy, selectedScreenId);
  //   setButtonLabel(seq?.custom.sequenceName || 'next');
  // }, [selectedScreenId, hierarchy]);

  return (
    <Fragment>
      <span className="form-label">{label}</span>
      <div className="dropdown">
        <button
          className="btn btn-secondary dropdown-toggle"
          type="button"
          id={id}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          {buttonLabel}
        </button>
        <div className="dropdown-menu" aria-labelledby={id}>
          <SequenceDropdown items={hierarchy} onChange={onChangeHandler} value={props.value} />
        </div>
      </div>
    </Fragment>
  );
};

export default CustomDropdownTemplate;
