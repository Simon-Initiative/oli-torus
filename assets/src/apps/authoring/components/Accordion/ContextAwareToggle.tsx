/* eslint-disable react/prop-types */
import React, { useContext } from 'react';
import { AccordionContext, useAccordionToggle } from 'react-bootstrap';

const ContextAwareToggle: React.FC<any> = ({ children, eventKey, callback }) => {
  const currentEventKey = useContext(AccordionContext);

  const decoratedOnClick = useAccordionToggle(eventKey, () => callback && callback(eventKey));

  const isCurrentEventKey = currentEventKey === eventKey;

  return (
    <button type="button" className='my-1 mr-2' onClick={decoratedOnClick}>
      {isCurrentEventKey ? (
        <i className="fa fa-angle-down"></i>
      ) : (
        <i className="fa fa-angle-right"></i>
      )}
    </button>
  );
};

export default ContextAwareToggle;
