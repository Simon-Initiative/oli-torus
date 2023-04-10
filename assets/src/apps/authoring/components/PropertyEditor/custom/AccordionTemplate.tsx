import React from 'react';
import { Accordion } from 'react-bootstrap';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';
interface AccordionProps {
  key: string;
  title: string;
  properties: any;
}

const AccordionTemplate: React.FC<AccordionProps> = (props) => {
  return (
    <Accordion className="aa-properties-editor" defaultActiveKey="0">
      <div className="aa-panel-section-title-bar">
        <div className="d-flex align-items-center">
          <ContextAwareToggle eventKey="0" />
          <span className="title">{props.title}</span>
        </div>
      </div>
      <Accordion.Collapse eventKey="0">
        <div className="grid grid-cols-12 mx-4">
          {props.properties.map((element: any) => (
            <div
              key={element.content.key}
              className={`${element.content.props.uiSchema.classNames || 'col-span-12'} inner`}
            >
              {element.content}
            </div>
          ))}
        </div>
      </Accordion.Collapse>
    </Accordion>
  );
};

export default AccordionTemplate;
