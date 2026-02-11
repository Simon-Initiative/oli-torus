import React, { ReactNode, useCallback, useEffect, useRef } from 'react';
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

// Selector for focusable elements
const FOCUSABLE_SELECTOR =
  'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export const PromptModal: React.FC<PromptModalProps> = ({
  title,
  onConfirm,
  onCancel,
  confirmText,
  cancelText,
  children,
  className,
}) => {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);
  const modalId = useRef(`prompt-modal-${Math.random().toString(36).substr(2, 9)}`);

  // Focus trap handler
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onCancel();
        return;
      }

      if (e.key !== 'Tab' || !modalRef.current) return;

      const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusableElements.length === 0) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          e.preventDefault();
          lastElement.focus();
        }
      } else {
        if (document.activeElement === lastElement) {
          e.preventDefault();
          firstElement.focus();
        }
      }
    },
    [onCancel],
  );

  useEffect(() => {
    // Save the currently focused element to restore later
    previousActiveElement.current = document.activeElement as HTMLElement;

    // Focus the first focusable element when modal opens
    if (modalRef.current) {
      const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusableElements.length > 0) {
        focusableElements[0].focus();
      }
    }

    // Add keyboard listener for focus trap and escape
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      // Return focus to the element that triggered the modal
      if (previousActiveElement.current) {
        previousActiveElement.current.focus();
      }
    };
  }, [handleKeyDown]);

  const titleId = `${modalId.current}-title`;

  return (
    <div
      ref={modalRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      className="fixed inset-0 z-50 flex items-center justify-center"
    >
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/20" aria-hidden="true" onClick={onCancel} />

      <Card.Card
        className={`w-96 relative border-[1px] border-gray-100 dark:border-gray-500 ${className}`}
      >
        <Card.Title>
          <b id={titleId}>{title}</b>
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
    </div>
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
