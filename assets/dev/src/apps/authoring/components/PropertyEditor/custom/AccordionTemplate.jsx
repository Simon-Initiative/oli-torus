import React from 'react';
import { Accordion } from 'react-bootstrap';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';
const AccordionTemplate = (props) => {
    return (<Accordion className="aa-properties-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0"/>
          <span className="title">{props.title}</span>
        </div>
      </div>
      <Accordion.Collapse eventKey="0">
        <div className="col-12">{props.properties.map((element) => element.content)}</div>
      </Accordion.Collapse>
    </Accordion>);
};
export default AccordionTemplate;
//# sourceMappingURL=AccordionTemplate.jsx.map