import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React from 'react';
import { Accordion, ListGroup } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import ContextAwareToggle from '../../Accordion/ContextAwareToggle';
export const SequenceDropdown = (props) => {
    const { items, onChange, value, showNextBtn } = props;
    const sequence = useSelector(selectSequence);
    // console.log(sequence);
    const sequenceDropDownItems = (items) => items.map((item, index) => {
        var _a;
        const title = ((_a = item.custom) === null || _a === void 0 ? void 0 : _a.sequenceName) || item.activitySlug;
        return (<Accordion key={`${index}`}>
          <ListGroup.Item as="li" className={`aa-sequence-item${item.children.length ? ' is-parent' : ''} ${item.custom.sequenceId === value ? 'active' : ''}`} key={`${item.custom.sequenceId}`} tabIndex={0}>
            <div className="aa-sequence-details-wrapper" onClick={(e) => onChange(item, e, false)}>
              <div className="details">
                {item.children.length ? (<ContextAwareToggle eventKey={`${index}`} className={`aa-sequence-item-toggle`}/>) : null}
                <span className="title">{title}</span>
              </div>
            </div>
            {item.children.length ? (<Accordion.Collapse eventKey={`${index}`}>
                <ListGroup as="ol" className="aa-sequence nested">
                  {sequenceDropDownItems(item.children)}
                </ListGroup>
              </Accordion.Collapse>) : null}
          </ListGroup.Item>
        </Accordion>);
    });
    return (<div className="aa-sequence-editor">
      <ListGroup as="ol" className="aa-sequence">
        {showNextBtn ? (<ListGroup.Item as="li" className={`aa-sequence-item`} key="next" onClick={(e) => onChange(null, e, true)} tabIndex={0}>
            <div className="aa-sequence-details-wrapper">
              <div className="details">
                <span className="title">Next Screen</span>
              </div>
            </div>
          </ListGroup.Item>) : null}
        {sequenceDropDownItems(items)}
      </ListGroup>
    </div>);
};
//# sourceMappingURL=SequenceDropdown.jsx.map