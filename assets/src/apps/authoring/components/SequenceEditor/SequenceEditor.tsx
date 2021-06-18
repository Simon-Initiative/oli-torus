import React from 'react';
import { Accordion, Card, ListGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const SequenceEditor: React.FC<any> = (props) => {
  const sequence = useSelector(selectSequence);

  return (
    <Accordion defaultActiveKey="0">
      <Card>
        <Card.Header>
          <ContextAwareToggle eventKey="0" />
          Sequence Editor
        </Card.Header>
        <Accordion.Collapse eventKey="0">
          <Card.Body>
            <ListGroup>
              {sequence.map((entry) => (
                <ListGroup.Item key={entry.custom.sequenceId}>
                  {entry.custom.sequenceName}
                </ListGroup.Item>
              ))}
            </ListGroup>
          </Card.Body>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  );
};

export default SequenceEditor;
