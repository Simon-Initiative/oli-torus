/* eslint-disable @typescript-eslint/ban-types */
import React, { Fragment, useEffect, useState } from 'react';
import { Dropdown } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import {
  SequenceEntry,
  SequenceEntryChild,
  findInSequence,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { SequenceDropdown } from './SequenceDropdown';

interface ScreenDropdownProps {
  id: string;
  label: string;
  value: string;
  onChange: (value?: string) => void;
  dropDownCSSClass?: string;
  buttonCSSClass?: string;
}
const ScreenDropdownTemplate: React.FC<ScreenDropdownProps> = (props) => {
  const { id, label, value, onChange, buttonCSSClass } = props;
  // console.log('ScreenDropdownTemplate', props);
  const sequence = useSelector(selectSequence);

  const [buttonLabel, setButtonLabel] = useState('Next Screen');
  const [hierarchy, setHierarchy] = useState(getHierarchy(sequence));

  useEffect(() => {
    if (value === 'next') {
      setButtonLabel('Next Screen');
      return;
    }
    if (value === 'endOfLesson') {
      setButtonLabel('End of lesson');
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
    item: SequenceEntry<SequenceEntryChild> | null,
    e: React.MouseEvent,
    isNext: boolean,
    isLessonEnd?: boolean,
  ) => {
    const itemId = isNext ? 'next' : isLessonEnd ? 'endOfLesson' : item?.custom.sequenceId;
    onChange(itemId);
  };

  return (
    <Fragment>
      {label && <span className="form-label">{label}</span>}
      <Dropdown>
        <Dropdown.Toggle
          variant="link"
          id={id}
          className={`${buttonCSSClass} form-control dropdown-toggle d-flex justify-content-between`}
        >
          {buttonLabel}
          <i className="fas fa-caret-down my-auto" />
        </Dropdown.Toggle>

        <Dropdown.Menu className="aa-sequence-editor-menu">
          <SequenceDropdown
            items={hierarchy}
            onChange={onChangeHandler}
            value={props.value}
            showNextBtn={true}
          />
        </Dropdown.Menu>
      </Dropdown>
    </Fragment>
  );
};

export default ScreenDropdownTemplate;
