import React from 'react';
import { Modal } from 'react-bootstrap';
import { IActivity } from '../../../../delivery/store/features/activities/slice';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';

export const InvalidScreenWarning: React.FC<{
  screens: IActivity[];
  onAccept: () => void;
  onCancel: () => void;
}> = ({ screens, onAccept, onCancel }) => (
  <AdvancedAuthoringModal show={true} onHide={onCancel}>
    <Modal.Header closeButton={true}>
      <h3 className="modal-title">Invalid screens detected</h3>
    </Modal.Header>
    <Modal.Body>
      <p>
        Screens that don&apos;t pass validation may not function as expected. Please check the paths
        for the following screens:
        <ul className="invalid-screen-list">
          {screens.map((screen) => (
            <li key={screen.id}>{screen.title}</li>
          ))}
        </ul>
      </p>
    </Modal.Body>
    <Modal.Footer>
      <button onClick={onCancel} className="btn btn-secondary">
        Cancel
      </button>
      <button onClick={onAccept} className="btn btn-primary">
        Preview Anyways
      </button>
    </Modal.Footer>
  </AdvancedAuthoringModal>
);
