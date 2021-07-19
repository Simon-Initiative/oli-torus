import React, { useEffect } from 'react';
import { Accordion, ListGroup, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../../../delivery/store/features/activities/slice';
import { selectCurrentRule, setCurrentRule } from '../../../authoring/store/app/slice';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const AdaptivityRuleList: React.FC<any> = (props) => {
  const dispatch = useDispatch();
  const currentActivity = useSelector(selectCurrentActivity);
  const currentRule = useSelector(selectCurrentRule);
  const rules = currentActivity?.authoring.rules || [];

  const handleSelectRule = (rule: any) => dispatch(setCurrentRule({ currentRule: rule }));

  useEffect(() => {
    rules.length > 0
      ? dispatch(setCurrentRule({ currentRule: rules[0] }))
      : dispatch(setCurrentRule({ currentRule: undefined }));
  }, [currentActivity]);

  return (
    <Accordion className="aa-adaptivity-rules" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">Adaptivity</span>
        </div>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
              New Rule
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
        <ListGroup className="aa-rules-list" as="ol">
          {rules.map((rule: any, index: any) => (
            <ListGroup.Item
              className="aa-rules-list-item"
              as="li"
              key={rule.id}
              active={rule.id === currentRule?.id}
              onClick={() => handleSelectRule(rule)}
            >
              {rule.name}
            </ListGroup.Item>
          ))}
        </ListGroup>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AdaptivityRuleList;
