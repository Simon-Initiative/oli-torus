import React from 'react';
import { Accordion, ListGroup } from 'react-bootstrap';
import {
  SequenceEntryChild,
  SequenceHierarchyItem,
  SequenceEntryType,
  SequenceEntry,
} from 'apps/delivery/store/features/groups/actions/sequence';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';
import {
  selectCurrentSequenceId,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import { useSelector } from 'react-redux';

interface SeqDropdownProps {
  items: SequenceHierarchyItem<SequenceEntryChild>[];
  onChange: (e: React.MouseEvent, item: null | SequenceHierarchyItem<SequenceEntryChild>) => void;
  value: string;
  showNextBtn: boolean;
}

export const SequenceDropdown: React.FC<SeqDropdownProps> = (props) => {
  const { items, onChange, value, showNextBtn } = props;
  const sequence = useSelector(selectSequence);
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  console.log(sequence);
  const handleNextClick = (e: React.MouseEvent) => {
    onChange(e, getNextScreen());
  };
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

  const sequenceDropDownItems = (items: any) =>
    items.map((item: SequenceHierarchyItem<SequenceEntryType>, index: number) => {
      const title = item.custom?.sequenceName || item.activitySlug;
      return (
        <Accordion key={`${index}`}>
          <ListGroup.Item
            as="li"
            className={`aa-sequence-item${item.children.length ? ' is-parent' : ''} ${
              item.custom.sequenceId === value ? 'active' : ''
            }`}
            key={`${item.custom.sequenceId}`}
            tabIndex={0}
          >
            <div className="aa-sequence-details-wrapper" onClick={(e) => onChange(e, item)}>
              <div className="details">
                {item.children.length ? (
                  <ContextAwareToggle eventKey={`${index}`} className={`aa-sequence-item-toggle`} />
                ) : null}
                <span className="title">{title}</span>
              </div>
            </div>
            {item.children.length ? (
              <Accordion.Collapse eventKey={`${index}`}>
                <ListGroup as="ol" className="aa-sequence nested">
                  {sequenceDropDownItems(item.children)}
                </ListGroup>
              </Accordion.Collapse>
            ) : null}
          </ListGroup.Item>
        </Accordion>
      );
    });

  return (
    <div className="aa-sequence-editor">
      <ListGroup as="ol" className="aa-sequence">
        {showNextBtn ? (
          <ListGroup.Item
            as="li"
            className={`aa-sequence-item`}
            key="next"
            onClick={(e) => handleNextClick(e)}
            tabIndex={0}
          >
            <div className="aa-sequence-details-wrapper">
              <div className="details">
                <span className="title">Next Screen</span>
              </div>
            </div>
          </ListGroup.Item>
        ) : null}
        {sequenceDropDownItems(items)}
      </ListGroup>
    </div>
  );
};
