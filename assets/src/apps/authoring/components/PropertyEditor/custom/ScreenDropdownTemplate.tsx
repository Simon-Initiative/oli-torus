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
import { Dropdown, DropdownButton } from 'react-bootstrap';

interface ScreenDropdownProps {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
}
const ScreenDropdownTemplate: React.FC<ScreenDropdownProps> = (props) => {
  const { id, label, value, onChange } = props;
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const seq = findInHierarchy(hierarchy, value);
  const buttonLabel = seq?.custom.sequenceName;

  const onChangeHandler = (e: React.MouseEvent, item: SequenceEntry<SequenceEntryChild> | null) => {
    onChange(item?.custom.sequenceId || 'next');
    //e.stopPropagation();
  };

  return (
    <Fragment>
      <span className="form-label">{label}</span>
      <div className="dropdown screenDropdown">
        <button
          className="btn btn-secondary dropdown-toggle d-flex justify-content-between"
          type="button"
          id={id}
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          {buttonLabel}
          <i className="fas fa-caret-down my-auto" />
        </button>
        <div className="dropdown-menu" aria-labelledby={id}>
          <SequenceDropdown
            items={hierarchy}
            onChange={onChangeHandler}
            value={props.value}
            showNextBtn={true}
          />
        </div>
      </div>
    </Fragment>
  );
};

export default ScreenDropdownTemplate;
