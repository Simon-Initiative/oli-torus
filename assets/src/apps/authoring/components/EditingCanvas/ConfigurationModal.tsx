import React, { useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';

interface ConfigModalProps {
  onClose: () => void;
  onSave: () => void;
  isOpen: boolean;
  bodyId?: string;
  fullscreen?: boolean;
  headerText?: string;
  customClassName?: string;
}

let instanceCounter = 0;

const ConfigurationModal: React.FC<ConfigModalProps> = ({
  isOpen,
  bodyId = 'configuration-modal-body',
  headerText = 'Configuration',
  fullscreen = false,
  customClassName = '',
  onClose,
  onSave,
}) => {
  const [instanceId, setInstanceId] = useState(-1);
  const [enforceFocus, setEnforceFocus] = useState(false);
  const [show, setShow] = useState(isOpen);

  useEffect(() => {
    if (show) {
      setInstanceId(instanceCounter++);
    } else {
      setInstanceId(-1);
    }
  }, [show]);

  useEffect(() => {
    if (instanceId === instanceCounter) {
      setEnforceFocus(true);
    } else {
      setEnforceFocus(false);
    }
  }, [instanceId]);

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
      dialogClassName={`config-modal ${customClassName} ${fullscreen ? 'modal-90w' : ''}`}
      show={show}
      onHide={handleCancelClick}
      enforceFocus={enforceFocus}
      style={{ overflow: 'auto' }}
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
