/* eslint-disable react/prop-types */
import React, { useContext } from 'react';
import { AccordionContext, useAccordionToggle } from 'react-bootstrap';

const ContextAwareToggle: React.FC<any> = ({ children, eventKey, callback }) => {
  const currentEventKey = useContext(AccordionContext);

  const decoratedOnClick = useAccordionToggle(eventKey, () => callback && callback(eventKey));

  const isCurrentEventKey = currentEventKey === eventKey;

  return (
    <button type="button" onClick={decoratedOnClick}>
      {isCurrentEventKey ? (
        <i className="fa fa-angle-down my-1 mr-2"></i>
      ) : (
        <i className="fa fa-angle-up my-1 mr-2"></i>
      )}
    </button>
  );
};

export default ContextAwareToggle;
