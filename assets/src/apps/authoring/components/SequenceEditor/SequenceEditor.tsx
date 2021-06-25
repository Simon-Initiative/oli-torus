import React from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../delivery/store/features/groups/actions/sequence';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const SequenceEditor: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentActivityId = useSelector(selectCurrentActivityId);
  const sequence = useSelector(selectSequence);

  const handleItemClick = (entry: SequenceEntry<SequenceEntryChild>) => {
    dispatch(setCurrentActivityId({ activityId: entry.activitySlug }));
  };

  return (
    <Accordion className="aa-sequence-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Sequence Editor</span>
        </div>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              New Sequence
            </Tooltip>
          }
        >
          <span>
            <button className="btn btn-link p-0">
              <i className="fa fa-plus" />
            </button>
          </span>
        </OverlayTrigger>
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup as="ol" className="aa-sequence">
          {sequence.map((entry, index) => (
            <ListGroup.Item
              as="li"
              className="aa-sequence-item"
              key={entry.custom.sequenceId}
              active={entry.activitySlug === currentActivityId}
              onClick={() => handleItemClick(entry)}
            >
              {entry.custom.sequenceName}
            </ListGroup.Item>
          ))}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default SequenceEditor;
