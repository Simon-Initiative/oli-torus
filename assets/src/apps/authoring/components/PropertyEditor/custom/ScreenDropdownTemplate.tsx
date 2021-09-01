/* eslint-disable @typescript-eslint/ban-types */
import {
  findInSequence,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { Fragment, useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { SequenceDropdown } from './SequenceDropdown';

interface ScreenDropdownProps {
  id: string;
  label: string;
  value: string;
  onChange: (value?: string) => void;
}
const ScreenDropdownTemplate: React.FC<ScreenDropdownProps> = (props) => {
  const { id, label, value, onChange } = props;
  console.log('ScreenDropdownTemplate', props);
  const sequence = useSelector(selectSequence);

  const [buttonLabel, setButtonLabel] = useState('Next Screen');
  const [hierarchy, setHierarchy] = useState(getHierarchy(sequence));

  useEffect(() => {
    if (value === 'next') {
      setButtonLabel('Next Screen');
      return;
    }
    if (sequence) {
      setHierarchy(getHierarchy(sequence));
      const entry = findInSequence(sequence, value);
      if (entry) {
        setButtonLabel(entry.custom.sequenceName);
        return;
      }
    }
    // TODO: should probably handle this scenario earlier in the data and auto correct
    setButtonLabel('Missing Screen!');
  }, [value, sequence]);

  const onChangeHandler = (
    e: React.MouseEvent,
    item: SequenceEntry<SequenceEntryChild> | null,
    isNext: boolean,
  ) => {
    const itemId = isNext ? 'next' : item?.custom.sequenceId;
    onChange(itemId);
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
