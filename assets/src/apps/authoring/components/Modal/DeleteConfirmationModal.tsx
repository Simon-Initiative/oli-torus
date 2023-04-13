import React, { Fragment } from 'react';
import { useEffect } from 'react';
import { useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';

interface ConfirmDeleteProps {
  show: boolean;
  elementType?: string;
  elementName?: string;
  cancelHandler: () => void;
  deleteHandler: () => void;
}

const ConfirmDelete: React.FC<ConfirmDeleteProps> = (props) => {
  const { show, elementType, elementName, cancelHandler, deleteHandler } = props;

  return (
    <AdvancedAuthoringModal show={show} onHide={cancelHandler}>
      <Modal.Header closeButton={true}>
        <h3 className="modal-title">{`Delete ${elementType}`}</h3>
      </Modal.Header>
      <Modal.Body>
        <label>{`Are you sure you want to delete ${elementName} ?`}</label>
      </Modal.Body>
      <Modal.Footer>
        <button id="btnCancel" className="btn btn-secondary" onClick={cancelHandler}>
          Cancel
        </button>
        <button id="btnDelete" className="btn btn-danger" onClick={deleteHandler}>
          {`Delete ${elementType}`}
        </button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
export default ConfirmDelete;
