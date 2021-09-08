import { NavigationAction, NavigationActionParams } from 'apps/authoring/types';
import {
  findInSequence,
  getHierarchy,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import React, { useState } from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import guid from 'utils/guid';
import { SequenceDropdown } from '../PropertyEditor/custom/SequenceDropdown';

interface ActionNavigationEditorProps {
  action: NavigationAction;
  onChange: (changes: NavigationActionParams) => void;
  onDelete: (changes: NavigationAction) => void;
}

const ActionNavigationEditor: React.FC<ActionNavigationEditorProps> = (props) => {
  const { action, onChange, onDelete } = props;
  const sequence = useSelector(selectSequence);
  const selsectedSequence = findInSequence(sequence, action?.params?.target);
  const [target, setTarget] = useState(selsectedSequence?.custom.sequenceName || 'next');
  const uuid = guid();
  const hierarchy = getHierarchy(sequence);

  const handleTargetChange = (e: any) => {
    const currentVal = e.target.value;
    setTarget(currentVal);
    onChange({ target: currentVal });
  };

  const onChangeHandler = (item: SequenceEntry<SequenceEntryChild> | null) => {
    const itemId = item?.custom.sequenceId;
    onChange({ target: itemId || 'next' });
    setTarget(item?.custom.sequenceName || 'next');
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
        <div className="dropdown dropup adaptivityDropdown">
          <button
            className="btn btn-secondary dropdown-toggle form-control form-control-sm"
            type="button"
            id={`drp-${uuid}`}
            data-toggle="dropdown"
            aria-haspopup="true"
            aria-expanded="false"
          />
          <div className="dropdown-menu" aria-labelledby={`drp-${uuid}`}>
            <SequenceDropdown
              items={hierarchy}
              onChange={onChangeHandler}
              value={target}
              showNextBtn={false}
            />
          </div>
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
            <button className="btn btn-link p-0 ml-1" onClick={() => onDelete(action)}>
              <i className="fa fa-trash-alt" />
            </button>
          </span>
        </OverlayTrigger>
      </div>
    </div>
  );
};

export default ActionNavigationEditor;
