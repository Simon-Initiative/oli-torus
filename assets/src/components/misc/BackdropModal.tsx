import React, { ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { CloseIcon } from 'components/misc/icons/Icons';
import { useToggle } from '../hooks/useToggle';

interface BackdropModalProps {
  title: string;
  children: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
  confirmText?: string;
  cancelText?: string;
}

export const BackdropModal: React.FC<BackdropModalProps> = ({
  title,
  onConfirm,
  onCancel,
  confirmText = 'Ok',
  cancelText = 'Cancel',
  children,
}) => {
  const [isVisible, setIsVisible] = useState(false);
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsVisible(true);
      requestAnimationFrame(() => {
        if (modalRef.current) {
          modalRef.current.focus();
        }
      });
    }, 100);

    return () => clearTimeout(timer);
  }, []);

  const handleClose = () => {
    setIsVisible(false);
    setTimeout(() => {
      onCancel?.();
    }, 300);
  };

  return (
    <div
      id="backdrop-modal"
      ref={modalRef}
      className={`fixed inset-0 z-50 transition-opacity duration-300 ${
        isVisible ? 'opacity-100' : 'opacity-0 pointer-events-none'
      }`}
      onClick={handleClose}
      onKeyDown={(e) => e.key === 'Escape' && handleClose()}
      tabIndex={0}
      role="dialog"
      aria-modal="true"
      aria-labelledby="backdrop-modal-title"
      aria-describedby="backdrop-modal-description"
    >
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/20 backdrop-blur-sm" aria-hidden="true" />

      {/* Modal */}
      <div className="flex w-1/2 m-auto min-h-full items-center justify-center">
        <div
          className={`p-4 sm:p-6 lg:py-8 transform transition duration-300 ${
            isVisible ? 'scale-100 opacity-100' : 'scale-95 opacity-0'
          }`}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="relative bg-white dark:bg-body-dark shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10">
            {/* Header */}
            <div className="flex justify-between items-center px-6 py-4 border-b">
              {title && (
                <h1
                  id="backdrop-modal-title"
                  className="text-xl font-semibold text-gray-900 dark:text-white"
                >
                  {title}
                </h1>
              )}
              <button
                type="button"
                onClick={handleClose}
                aria-label="Close"
                className="text-gray-400 hover:text-gray-900 hover:bg-gray-200 dark:hover:bg-gray-600 dark:hover:text-white rounded-lg text-sm w-8 h-8 inline-flex justify-center items-center"
              >
                <CloseIcon className="w-4 h-4" />
                <span className="sr-only">Close modal</span>
              </button>
            </div>

            {/* Body */}
            <div className="p-6">{children}</div>

            {/* Footer */}
            <div className="flex justify-end p-6 space-x-2">
              <button
                onClick={handleClose}
                className="h-8 px-3 border rounded-md inline-flex items-center
              bg-white text-[#006cd9] border-[#8ab8e5] hover:bg-[#0062F2] hover:text-white
              dark:bg-gray-800 dark:text-[#197adc] dark:border-[#197adc]
              dark:hover:bg-[#0062F2] dark:hover:text-white dark:hover:border-[#0062F2]"
              >
                {cancelText}
              </button>
              <button
                onClick={onConfirm}
                className="h-8 px-5 py-3 text-white rounded-md inline-flex items-center gap-2
              bg-[#0062F2] hover:bg-[#0075EB] dark:bg-[#0062F2] dark:hover:bg-[#0D70FF]"
              >
                {confirmText}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const useBackdropModal = (
  prompt: string | ReactNode,
  onConfirm?: () => void,
  onCancel?: () => void,
  title = 'Confirmation',
  confirmText = 'Ok',
  cancelText = 'Cancel',
) => {
  const [isOpen, , showModal, hideModal] = useToggle();
  const onConfirmHandler = useCallback(() => {
    hideModal();
    onConfirm?.();
  }, [hideModal, onConfirm]);
  const onCancelHandler = useCallback(() => {
    hideModal();
    onCancel?.();
  }, [hideModal, onCancel]);
  const Modal = isOpen ? (
    <BackdropModal
      onConfirm={onConfirmHandler}
      onCancel={onCancelHandler}
      title={title}
      confirmText={confirmText}
      cancelText={cancelText}
    >
      {prompt}
    </BackdropModal>
  ) : null;
  return {
    isOpen,
    showModal,
    hideModal,
    Modal,
  };
};
