import { findInSequence } from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { useState, useEffect } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import guid from 'utils/guid';
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import ScreenDropdownTemplate from '../PropertyEditor/custom/ScreenDropdownTemplate';
const ActionNavigationEditor = (props) => {
    var _a;
    const { action, allowDelete, onChange, onDelete } = props;
    const sequence = useSelector(selectSequence);
    const selectedSequence = findInSequence(sequence, (_a = action === null || action === void 0 ? void 0 : action.params) === null || _a === void 0 ? void 0 : _a.target);
    const [target, setTarget] = useState((selectedSequence === null || selectedSequence === void 0 ? void 0 : selectedSequence.custom.sequenceId) || 'next');
    const [showConfirmDelete, setShowConfirmDelete] = useState(false);
    const uuid = guid();
    // When the 'Navigate to' Option is changed
    useEffect(() => {
        setTarget((selectedSequence === null || selectedSequence === void 0 ? void 0 : selectedSequence.custom.sequenceId) || 'next');
    }, [selectedSequence]);
    const onChangeHandler = (sequenceId) => {
        // console.log('onChange picker', sequenceId);
        onChange({ target: sequenceId || 'next' });
        setTarget(sequenceId || 'next');
    };
    return (<div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-navigation-${uuid}`}>
        SequenceId
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <i className="fa fa-compass mr-1"/>
            Navigate To
          </div>
        </div>
        <ScreenDropdownTemplate id={`action-navigation-${uuid}`} label="" value={target} onChange={onChangeHandler} dropDownCSSClass="adaptivityDropdown form-control" buttonCSSClass="form-control-sm"/>
        {allowDelete && (<OverlayTrigger placement="top" delay={{ show: 150, hide: 150 }} overlay={<Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                Delete Action
              </Tooltip>}>
            <span>
              <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
                <i className="fa fa-trash-alt"/>
              </button>
            </span>
          </OverlayTrigger>)}
      </div>
      {showConfirmDelete && (<ConfirmDelete show={showConfirmDelete} elementType="Action" elementName="this navigation action" deleteHandler={() => {
                onDelete(action);
                setShowConfirmDelete(false);
            }} cancelHandler={() => {
                setShowConfirmDelete(false);
            }}/>)}
    </div>);
};
export default ActionNavigationEditor;
//# sourceMappingURL=ActionNavigationEditor.jsx.map