import {
  SequenceEntryChild,
  SequenceEntryType,
  SequenceHierarchyItem,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React from 'react';
import { Accordion, ListGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';

interface SeqDropdownProps {
  items: SequenceHierarchyItem<SequenceEntryChild>[];
  onChange: (
    e: React.MouseEvent,
    item: null | SequenceHierarchyItem<SequenceEntryChild>,
    isNextButton: boolean,
  ) => void;
  value: string;
  showNextBtn: boolean;
}

export const SequenceDropdown: React.FC<SeqDropdownProps> = (props) => {
  const { items, onChange, value, showNextBtn } = props;
  const sequence = useSelector(selectSequence);
  console.log(sequence);

  const sequenceDropDownItems = (items: SequenceHierarchyItem<SequenceEntryType>[]) =>
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
            <div className="aa-sequence-details-wrapper" onClick={(e) => onChange(e, item, false)}>
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
            onClick={(e) => onChange(e, null, true)}
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
