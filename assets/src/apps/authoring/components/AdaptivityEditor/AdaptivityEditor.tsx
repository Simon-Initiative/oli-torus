import React from 'react';
import { Accordion, Card, ListGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const AdaptivityEditor: React.FC<any> = (props) => {
  const currentActivity = useSelector(selectCurrentActivity);
  /* console.log('CA', { currentActivity }); */
  const rules = currentActivity?.model.authoring.rules || [];

  return (
    <Accordion defaultActiveKey="0">
      <Card>
        <Card.Header>
          <ContextAwareToggle eventKey="0" />
          Adaptivity
        </Card.Header>
        <Accordion.Collapse eventKey="0">
          <Card.Body>
            <ListGroup>
              {rules.map((rule: any) => (
                <ListGroup.Item key={rule.id}>{rule.name}</ListGroup.Item>
              ))}
            </ListGroup>
          </Card.Body>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  );
};

export default AdaptivityEditor;
