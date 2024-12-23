import React from 'react';
import { Modal } from 'react-bootstrap';

interface ShowInformationModalProps {
  show: boolean;
  title?: string; // Optional title will override the automatic title of `Delete ${elementType}`
  explanation?: string; // Optional additional explanation of what's going to happen.
  cancelHandler: () => void;
}

const ShowInformationModal: React.FC<ShowInformationModalProps> = (props) => {
  const { show, cancelHandler, title, explanation } = props;
  return (
    <Modal show={show} onHide={cancelHandler}>
      <Modal.Header closeButton={true} className="px-8 pb-0">
        <h3 className="modal-title font-bold">{title}</h3>
      </Modal.Header>
      <Modal.Body className="px-8">{explanation && <p>{explanation}</p>}</Modal.Body>
      <Modal.Footer className="px-8 pb-6 flex-row justify-items-stretch"></Modal.Footer>
    </Modal>
  );
};
export default ShowInformationModal;
