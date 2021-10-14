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
  const [isTopMostModal, setIsTopMostModal] = useState(false);
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

  useEffect(() => {
    //Need to add logic to identify if the modal is the top most modal.
    //This is dummy condition to test. will inform @Ben about the same.
    //There are 2 ways to fix the issue.
    //1) remove the TabIndex attribute from the modal (tricky)
    //2) apply enforceFocus=true for the top most modal
    //'config-editor-e:7GXIDVNS1P0SKGkMIeJrY' is the id of the top most modal. This logic needs to come from somewhere else
    //Also, style={{ overflow: 'auto' }} in the Modal because when we open the second modal and close it, it was impossible to scroll the first modal
    setIsTopMostModal(bodyId === 'config-editor-e:7GXIDVNS1P0SKGkMIeJrY');
  }, [bodyId]);

  return (
    <Modal
      dialogClassName={`config-modal ${fullscreen ? 'modal-90w' : ''}`}
      show={show}
      onHide={handleCancelClick}
      enforceFocus={isTopMostModal}
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
