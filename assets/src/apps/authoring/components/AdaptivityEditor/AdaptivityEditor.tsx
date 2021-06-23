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
    <Accordion className="aa-adaptivity-rules" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Adaptivity</span>
        </div>
        <i className="fa fa-plus"></i>
      </div>
      <Accordion.Collapse eventKey="0">
        <ListGroup className="aa-rules-list" as="ol">
          {rules.map((rule: any) => (
            <ListGroup.Item className="aa-rules-list-item" as="li" key={rule.id}>
              {rule.name}
            </ListGroup.Item>
          ))}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AdaptivityEditor;
