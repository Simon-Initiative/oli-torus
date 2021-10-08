import React, { useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';

interface ConfigModalProps {
  onClose: () => void;
  onSave: () => void;
  isOpen: boolean;
  bodyId?: string;
  fullscreen?: boolean;
  headerText?: string;
}

const ConfigurationModal: React.FC<ConfigModalProps> = ({
  isOpen,
  bodyId = 'configuration-modal-body',
  headerText = 'Configuration',
  fullscreen = false,
  onClose,
  onSave,
}) => {
  const [show, setShow] = useState(isOpen);

  useEffect(() => {
    setShow(isOpen);
  }, [isOpen]);

  const handleCancelClick = () => {
    setShow(false);
    onClose();
  };

  const handleSaveClick = () => {
    setShow(false);
    onSave();
  };

  return (
    <Modal
      dialogClassName={`config-modal ${fullscreen ? 'modal-90w' : ''}`}
      show={show}
      onHide={handleCancelClick}
    >
      <Modal.Header>
        <span className="title">{headerText}</span>
      </Modal.Header>
      <Modal.Body id={bodyId}></Modal.Body>
      <Modal.Footer>
        <button type="button" onClick={handleSaveClick} className="btn btn-primary">
          Save
        </button>
        <button
          type="button"
          onClick={handleCancelClick}
          className="btn btn-secondary"
          data-dismiss="modal"
        >
          Cancel
        </button>
      </Modal.Footer>
    </Modal>
  );
};

export default ConfigurationModal;
