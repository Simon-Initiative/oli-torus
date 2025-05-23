import React, { ReactNode, useCallback } from 'react';
import { useToggle } from '../hooks/useToggle';
import { Button } from './Button';
import { Card } from './Card';

interface PromptModalProps {
  title: string;
  children: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
  confirmText?: string;
  cancelText?: string;
  className?: string;
}

export const PromptModal: React.FC<PromptModalProps> = ({
  title,
  onConfirm,
  onCancel,
  confirmText,
  cancelText,
  children,
  className,
}) => {
  return (
    <Card.Card
      className={`w-96 fixed top-1/3 inset-x-0 mx-auto border-[1px] border-gray-100 dark:border-gray-500 ${className} z-50`}
    >
      <Card.Title>
        <b>{title}</b>
      </Card.Title>
      <Card.Content>
        <div>{children}</div>

        <div className="flex flex-row items-center justify-end mt-6">
          <Button onClick={onCancel} className="min-w-[6rem]" variant="secondary">
            {cancelText}
          </Button>
          <Button onClick={onConfirm} className="min-w-[6rem]">
            {confirmText}
          </Button>
        </div>
      </Card.Content>
    </Card.Card>
  );
};

PromptModal.defaultProps = {
  confirmText: 'Ok',
  cancelText: 'Cancel',
  className: '',
};

/** Helper hook to display a modal prompt
 *
 * const { showModal, Modal } = usePromptModal('Are you sure?', () => {...});
 *
 * in render():
 *   {Modal}
 *
 * When you want to display it, call showModal()
 *
 */
export const usePromptModal = (
  prompt: string | ReactNode,
  onConfirm: undefined | (() => void) = undefined,
  onCancel: undefined | (() => void) = undefined,
  title = 'Confirmation',
) => {
  const [isOpen, , showModal, hideModal] = useToggle();

  const onConfirmHandler = useCallback(() => {
    hideModal();
    onConfirm && onConfirm();
  }, [hideModal, onConfirm]);

  const onCancelHandler = useCallback(() => {
    hideModal();
    onCancel && onCancel();
  }, [hideModal, onCancel]);

  const Modal = isOpen ? (
    <PromptModal onConfirm={onConfirmHandler} onCancel={onCancelHandler} title={title}>
      {prompt}
    </PromptModal>
  ) : null;

  return {
    isOpen,
    showModal,
    hideModal,
    Modal,
  };
};
