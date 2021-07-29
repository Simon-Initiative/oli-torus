import React, { useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import guid from 'utils/guid';

const ActionNavigationEditor = (props: any) => {
  const { action, onChange } = props;
  const [target, setTarget] = useState(action?.params?.target || '');
  const uuid = guid();

  const handleTargetChange = (e: any) => {
    const currentVal = e.target.value;
    setTarget(currentVal);
    onChange({ target: currentVal });
  };

  return (
    <div className="aa-action d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`action-navigation-${uuid}`}>
        SequenceId
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        <div className="input-group-prepend">
          <div className="input-group-text">
            <i className="fa fa-compass mr-1" />
            Navigate To
          </div>
        </div>
        <input
          type="text"
          className="form-control form-control-sm"
          id={`action-navigation-${uuid}`}
          placeholder="SequenceId"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          onBlur={(e) => handleTargetChange(e)}
          title={target}
        />
      </div>
      <OverlayTrigger
        placement="top"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Delete Action
          </Tooltip>
        }
      >
        <span>
          <button className="btn btn-link p-0 ml-1">
            <i className="fa fa-trash-alt" />
          </button>
        </span>
      </OverlayTrigger>
    </div>
  );
};

export default ActionNavigationEditor;
