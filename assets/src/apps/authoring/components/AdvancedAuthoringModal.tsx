import { Modal, ModalProps } from 'react-bootstrap';
import React, { useContext, useState } from 'react';

//  This helps us target our react-bootstrap modals to be within the shadow-dom that the advanced authoring app lives.
const ModalContext = React.createContext<HTMLDivElement | null>(null);

export const ModalContainer: React.FC = ({ children }) => {
  const [modalContainer, setModalContainer] = useState<HTMLDivElement | null>(null);

  return (
    <div>
      <ModalContext.Provider value={modalContainer}>{children}</ModalContext.Provider>
      <div id="advanced-authoring-modals" ref={setModalContainer}></div>
    </div>
  );
};

export const AdvancedAuthoringModal: React.FC<ModalProps> = (props) => {
  const container = useContext(ModalContext);
  if (!container) return null;
  return (
    <Modal {...props} container={container}>
      {props.children}
    </Modal>
  );
};
