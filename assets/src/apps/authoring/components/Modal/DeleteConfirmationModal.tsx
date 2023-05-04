import React from 'react';
import { Modal } from 'react-bootstrap';

interface ConfirmDeleteProps {
  show: boolean;
  elementType?: string; // What's a description of the type of thing we're deleting?
  elementName?: string; // What's the specific name of the thing we're deleting?
  title?: string; // Optional title will override the automatic title of `Delete ${elementType}`
  explanation?: string; // Optional additional explanation of what's going to happen.
  cancelHandler: () => void;
  deleteHandler: () => void;
}

const ConfirmDelete: React.FC<ConfirmDeleteProps> = (props) => {
  const { show, elementType, elementName, cancelHandler, deleteHandler, explanation } = props;

  const title = props.title || `Delete ${elementType}`;

  return (
    <Modal show={show} onHide={cancelHandler}>
      <Modal.Header closeButton={true} className="px-8 pb-0">
        <h3 className="modal-title font-bold">{title}</h3>
      </Modal.Header>
      <Modal.Body className="px-8">
        {elementName && <label>{`Are you sure you want to delete ${elementName} ?`}</label>}
        {explanation && <p>{explanation}</p>}
      </Modal.Body>
      <Modal.Footer className="px-8 pb-6 flex-row justify-items-stretch">
        <button id="btnDelete" className="btn btn-danger flex-grow basis-1" onClick={deleteHandler}>
          {`Delete ${elementType}`}
        </button>
        <button
          id="btnCancel"
          className="btn btn-primary flex-grow basis-1"
          onClick={cancelHandler}
        >
          Cancel
        </button>
      </Modal.Footer>
    </Modal>
  );
};
export default ConfirmDelete;
