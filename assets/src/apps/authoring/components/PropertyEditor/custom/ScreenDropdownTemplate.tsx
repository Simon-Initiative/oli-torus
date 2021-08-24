/* eslint-disable @typescript-eslint/ban-types */
import React, { Fragment } from 'react';
import { SequenceDropdown } from './SequenceDropdown';
import {
  findInHierarchy,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';

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

  const onChangeHandler = (e: React.MouseEvent, item: SequenceEntry<SequenceEntryChild>) => {
    e.stopPropagation();
    //setSelectedScreenId(item.custom.sequenceId);
    onChange(item.custom.sequenceId);
  };

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

export default ScreenDropdownTemplate;
