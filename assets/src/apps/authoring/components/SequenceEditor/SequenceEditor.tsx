import React from 'react';
import { Accordion, Card, ListGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const SequenceEditor: React.FC<any> = (props) => {
  const sequence = useSelector(selectSequence);

  return (
    <Accordion className="aa-sequence-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Sequence Editor</span>
        </div>
        <i className="fa fa-plus"></i>
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup as="ol" className="aa-sequence">
          {sequence.map((entry) => (
            <ListGroup.Item as="li" className="aa-sequence-item" key={entry.custom.sequenceId}>
              {entry.custom.sequenceName}
            </ListGroup.Item>
          ))}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default SequenceEditor;
