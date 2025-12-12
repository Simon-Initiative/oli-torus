import React, { PropsWithChildren, useCallback, useEffect, useRef } from 'react';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';

interface Modal {
  modal: any;
}

export enum ModalSize {
  SMALL = 'sm',
  MEDIUM = 'md',
  LARGE = 'lg',
  X_LARGE = 'xlg',
}

export interface ModalProps {
  okLabel?: string;
  okClassName?: string;
  cancelLabel?: string;
  disableOk?: boolean;
  backdrop?: boolean | 'static';
  keyboard?: boolean;
  hideDialogCloseButton?: boolean;
  title: string;
  hideOkButton?: boolean;
  hideCancelButton?: boolean;
  onOk?: () => void;
  onCancel?: () => void;
  size?: ModalSize;
  footer?: any;
}

// Selector for focusable elements
const FOCUSABLE_SELECTOR =
  'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export const Modal = (props: PropsWithChildren<ModalProps>) => {
  const { children } = props;
  const modal = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);
  const modalId = useRef(`modal-${Math.random().toString(36).substr(2, 9)}`);

  const okLabel = props.okLabel !== undefined ? props.okLabel : 'Ok';
  const cancelLabel = props.cancelLabel !== undefined ? props.cancelLabel : 'Cancel';
  const okClassName = props.okClassName !== undefined ? props.okClassName : 'primary';
  const size = props.size || 'lg';

  // Focus trap handler
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (e.key !== 'Tab' || !modal.current) return;

    const focusableElements = modal.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
    if (focusableElements.length === 0) return;

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    if (e.shiftKey) {
      // Shift + Tab: if on first element, go to last
      if (document.activeElement === firstElement) {
        e.preventDefault();
        lastElement.focus();
      }
    } else {
      // Tab: if on last element, go to first
      if (document.activeElement === lastElement) {
        e.preventDefault();
        firstElement.focus();
      }
    }
  }, []);

  useEffect(() => {
    if (modal.current) {
      const currentModal = modal.current;

      // Save the currently focused element to restore later
      previousActiveElement.current = document.activeElement as HTMLElement;

      (window as any).$(currentModal).modal('show');

      // Focus the first focusable element when modal opens
      $(currentModal).on('shown.bs.modal', () => {
        const focusableElements = currentModal.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
        if (focusableElements.length > 0) {
          focusableElements[0].focus();
        }
      });

      $(currentModal).on('hidden.bs.modal', (e) => {
        onCancel(e);
        // Return focus to the element that triggered the modal
        if (previousActiveElement.current) {
          previousActiveElement.current.focus();
        }
      });

      // Add focus trap listener
      document.addEventListener('keydown', handleKeyDown);

      return () => {
        document.removeEventListener('keydown', handleKeyDown);
        (window as any).$(currentModal).modal('hide');
      };
    }
  }, [handleKeyDown]);

  const onCancel = (e: any) => {
    e.preventDefault();
    if (props.onCancel) props.onCancel();
  };

  const onOk = (e: any) => {
    e.preventDefault();
    if (props.onOk) props.onOk();
  };

  const titleId = `${modalId.current}-title`;

  return (
    <div
      ref={modal}
      className={classNames(
        'modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto',
      )}
      data-bs-backdrop={props.backdrop}
      data-bs-keyboard={valueOr(props.keyboard, true)}
      tabIndex={-1}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
    >
      <div className={`modal-dialog modal-${size} relative w-auto pointer-events-none`}>
        <div className="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none text-current">
          <div className="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
            <h5 className="text-xl font-medium leading-normal" id={titleId}>
              {props.title}
            </h5>
            <button
              type="button"
              className="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 hover:text-black hover:opacity-75 hover:no-underline focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              data-bs-dismiss="modal"
              aria-label="Close"
            >
              <i className="fa-solid fa-xmark fa-xl"></i>
            </button>
          </div>
          <div className="modal-body relative p-4 pt-0">{children}</div>
          <div className="modal-footer flex flex-shrink-0 flex-wrap items-center justify-end p-4 border-t border-gray-200 rounded-b-md">
            {props.footer ? (
              props.footer
            ) : (
              <>
                {props.hideCancelButton === true ? null : (
                  <button
                    type="button"
                    className="btn btn-link ml-2"
                    onClick={onCancel}
                    data-bs-dismiss="modal"
                  >
                    {cancelLabel}
                  </button>
                )}
                {props.hideOkButton === true ? null : (
                  <button
                    disabled={props.disableOk}
                    type="button"
                    onClick={onOk}
                    className={`btn btn-${okClassName} ml-2`}
                  >
                    {okLabel}
                  </button>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

Modal.defaultProps = {
  backdrop: true,
};
