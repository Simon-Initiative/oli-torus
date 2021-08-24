import React from 'react';
import { Accordion, ListGroup } from 'react-bootstrap';
import {
  SequenceEntryChild,
  SequenceHierarchyItem,
  SequenceEntryType,
} from 'apps/delivery/store/features/groups/actions/sequence';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';

interface SeqDropdownProps {
  items: SequenceHierarchyItem<SequenceEntryChild>[];
  onChange: (e: React.MouseEvent, item: SequenceHierarchyItem<SequenceEntryChild>) => void;
  value: string;
}

export const SequenceDropdown: React.FC<SeqDropdownProps> = (props) => {
  const { items, onChange, value } = props;

  return (
    <div className="aa-sequence-editor">
      <ListGroup as="ol" className="aa-sequence">
        {items.map((item: SequenceHierarchyItem<SequenceEntryType>, index: number) => {
          const title = item.custom?.sequenceName || item.activitySlug;
          return (
            <Accordion key={`${index}`}>
              <ListGroup.Item
                as="li"
                className={`aa-sequence-item${item.children.length ? ' is-parent' : ''}`}
                key={`${item.custom.sequenceId}`}
                onClick={(e) => onChange(e, item)}
                tabIndex={0}
              >
                <div className="aa-sequence-details-wrapper">
                  <div className="details">
                    {item.children.length ? (
                      <ContextAwareToggle
                        eventKey={`${index}`}
                        className={`aa-sequence-item-toggle`}
                      />
                    ) : null}
                    <span className="title">{title}</span>
                  </div>
                </div>
                {item.children.length ? (
                  <Accordion.Collapse eventKey={`${index}`}>
                    <ListGroup as="ol" className="aa-sequence nested">
                      <SequenceDropdown items={item.children} onChange={onChange} value={value} />
                    </ListGroup>
                  </Accordion.Collapse>
                ) : null}
              </ListGroup.Item>
            </Accordion>
          );
        })}
      </ListGroup>
    </div>
  );
};
