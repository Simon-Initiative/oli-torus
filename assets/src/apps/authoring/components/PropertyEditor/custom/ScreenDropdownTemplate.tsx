/* eslint-disable @typescript-eslint/ban-types */
import React, { Fragment, useState } from 'react';
import { SequenceDropdown } from './SequenceDropdown';
import {
  findInHierarchy,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
  SequenceEntryType,
  SequenceHierarchyItem,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectCurrentSequenceId, selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';
import { Dropdown, DropdownButton } from 'react-bootstrap';

interface ScreenDropdownProps {
  id: string;
  label: string;
  value: string;
  onChange: (value?: string) => void;
}
const ScreenDropdownTemplate: React.FC<ScreenDropdownProps> = (props) => {
  const { id, label, value, onChange } = props;
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  const hierarchy = getHierarchy(sequence);
  const seq = findInHierarchy(hierarchy, value);

  const getNextScreen = () => {
    const currentIndex = sequence.findIndex(
      (entry) => entry.custom.sequenceId === currentSequenceId,
    );
    let nextSequenceEntry: SequenceEntry<SequenceEntryType> | null = null;
    let nextIndex = currentIndex + 1;
    nextSequenceEntry = sequence[nextIndex];
    while (nextSequenceEntry?.custom?.isBank || nextSequenceEntry?.custom?.isLayer) {
      // for layers if you try to navigate it should go to first child
      const firstChild = sequence.find(
        (entry) =>
          entry.custom?.layerRef ===
          (nextSequenceEntry as SequenceEntry<SequenceEntryType>).custom.sequenceId,
      );
      if (!firstChild) {
        continue;
      }
      nextSequenceEntry = firstChild;
    }
    while (nextSequenceEntry?.custom.layerRef === currentSequenceId) {
      nextIndex++;
      nextSequenceEntry = sequence[nextIndex];
    }
    return nextSequenceEntry as SequenceHierarchyItem<SequenceEntryChild>;
  };

  const setButtonLabel = (seq?: SequenceHierarchyItem<SequenceEntryChild>) =>{
    const nextSequenceEntry = getNextScreen();
    if(seq && seq.custom.sequenceId !== nextSequenceEntry.custom.sequenceId){
      return seq.custom.sequenceName;
    }
    return 'Next Screen';
  }

  const onChangeHandler = (e: React.MouseEvent, item: SequenceEntry<SequenceEntryChild> | null, isNext: boolean) => {
    if(isNext){
      item = getNextScreen();
    }
    onChange(item?.custom.sequenceId);
  };

  const buttonLabel = setButtonLabel(seq);

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
