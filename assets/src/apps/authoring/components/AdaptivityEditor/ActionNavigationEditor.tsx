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
import ConfirmDelete from '../Modal/DeleteConfirmationModal';
import ScreenDropdownTemplate from '../PropertyEditor/custom/ScreenDropdownTemplate';

interface ActionNavigationEditorProps {
  action: NavigationAction;
  allowDelete: boolean;
  onChange: (changes: NavigationActionParams) => void;
  onDelete: (changes: NavigationAction) => void;
}

const ActionNavigationEditor: React.FC<ActionNavigationEditorProps> = (props) => {
  const { action, allowDelete, onChange, onDelete } = props;
  const sequence = useSelector(selectSequence);
  const selectedSequence = findInSequence(sequence, action?.params?.target);
  const [target, setTarget] = useState(selectedSequence?.custom.sequenceId || 'next');
  const [showConfirmDelete, setShowConfirmDelete] = useState<boolean>(false);
  const uuid = guid();

  const onChangeHandler = (sequenceId: string) => {
    // console.log('onChange picker', sequenceId);
    onChange({ target: sequenceId || 'next' });
    setTarget(sequenceId || 'next');
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
        <ScreenDropdownTemplate
          id={`action-navigation-${uuid}`}
          label=""
          value={target}
          onChange={onChangeHandler}
          dropDownCSSClass="adaptivityDropdown form-control"
          buttonCSSClass="form-control-sm"
        />
        {allowDelete && (
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
              <button className="btn btn-link p-0 ml-1" onClick={() => setShowConfirmDelete(true)}>
                <i className="fa fa-trash-alt" />
              </button>
            </span>
          </OverlayTrigger>
        )}
      </div>
      {showConfirmDelete && (
        <ConfirmDelete
          show={showConfirmDelete}
          elementType="Action"
          elementName="this navigation action"
          deleteHandler={() => {
            onDelete(action);
            setShowConfirmDelete(false);
          }}
          cancelHandler={() => {
            setShowConfirmDelete(false);
          }}
        />
      )}
    </div>
  );
};

export default ActionNavigationEditor;
