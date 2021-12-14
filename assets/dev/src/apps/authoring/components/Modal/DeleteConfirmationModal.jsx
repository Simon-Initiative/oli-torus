import React, { Fragment } from 'react';
import { useEffect } from 'react';
import { useState } from 'react';
import { Modal } from 'react-bootstrap';
const ConfirmDelete = (props) => {
    const { show, elementType, elementName, cancelHandler, deleteHandler } = props;
    const [display, setDisplay] = useState(false);
    useEffect(() => {
        setDisplay(show);
    }, [show]);
    return (<Fragment>
      <Modal show={display} onHide={cancelHandler}>
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
      </Modal>
    </Fragment>);
};
export default ConfirmDelete;
//# sourceMappingURL=DeleteConfirmationModal.jsx.map