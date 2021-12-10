import React, { useContext } from 'react';
import { AccordionContext, useAccordionToggle } from 'react-bootstrap';

const ContextAwareToggle: React.FC<any> = ({ eventKey, callback, className }) => {
  const currentEventKey = useContext(AccordionContext);

  const decoratedOnClick = useAccordionToggle(eventKey, (e) => {
    e.stopPropagation();
    callback && callback(eventKey);
  });

  const isCurrentEventKey = currentEventKey === eventKey;

  const toggleButtonRef = React.useRef<HTMLButtonElement>(null);

  React.useEffect(() => {
    const handler = (e: any) => {
      /* console.log('toggleButtonRef', { ref: toggleButtonRef.current, e, isCurrentEventKey }); */
      if (e.detail === 'expand' && isCurrentEventKey) {
        // already expanded
        return;
      }
      if (e.detail === 'collapse' && !isCurrentEventKey) {
        // already collapsed
        return;
      }
      if (toggleButtonRef.current) {
        toggleButtonRef.current.click();
      }
    };
    document.addEventListener(eventKey, handler);

    return () => {
      document.removeEventListener(eventKey, handler);
    };
  }, [decoratedOnClick, eventKey, toggleButtonRef.current, isCurrentEventKey]);

  return (
    <button
      type="button"
      ref={toggleButtonRef}
      className={`btn btn-link p-0 mr-1 ${className ? className : ''}`}
      onClick={decoratedOnClick}
    >
      {isCurrentEventKey ? (
        <i className="fa fa-angle-down"></i>
      ) : (
        <i className="fa fa-angle-right"></i>
      )}
    </button>
  );
};

export default ContextAwareToggle;
