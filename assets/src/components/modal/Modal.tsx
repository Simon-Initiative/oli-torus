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
  okTextClassName?: string;
  cancelLabel?: string;
  cancelClassName?: string;
  cancelTextClassName?: string;
  disableOk?: boolean;
  reverseButtonOrder?: boolean;
  backdrop?: boolean | 'static';
  keyboard?: boolean;
  hideDialogCloseButton?: boolean;
  title: string;
  titleClassName?: string;
  hideOkButton?: boolean;
  hideCancelButton?: boolean;
  onOk?: () => void;
  onCancel?: () => void;
  size?: ModalSize;
  footer?: any;
  contentClassName?: string;
  headerClassName?: string;
  bodyClassName?: string;
  footerClassName?: string;
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
  const okClassName = props.okClassName !== undefined ? props.okClassName : 'btn btn-primary ml-2';
  const okTextClassName = props.okTextClassName || '';
  const cancelClassName =
    props.cancelClassName !== undefined ? props.cancelClassName : 'btn btn-link ml-2';
  const cancelTextClassName = props.cancelTextClassName || '';
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
        <div
          className={classNames(
            'modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none text-current',
            props.contentClassName,
          )}
        >
          <div
            className={classNames(
              'modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md',
              props.headerClassName,
            )}
          >
            <h5
              className={classNames('text-xl font-medium leading-normal', props.titleClassName)}
              id={titleId}
            >
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
          <div className={classNames('modal-body relative p-4 pt-0', props.bodyClassName)}>
            {children}
          </div>
          <div
            className={classNames(
              'modal-footer flex flex-shrink-0 flex-wrap items-center justify-end p-4 border-t border-gray-200 rounded-b-md',
              props.footerClassName,
            )}
          >
            {props.footer ? (
              props.footer
            ) : (
              <>
                {props.reverseButtonOrder ? (
                  <>
                    {props.hideOkButton ? null : (
                      <button
                        disabled={props.disableOk}
                        type="button"
                        onClick={onOk}
                        className={okClassName}
                      >
                        {okTextClassName ? (
                          <span className={okTextClassName}>{okLabel}</span>
                        ) : (
                          okLabel
                        )}
                      </button>
                    )}
                    {props.hideCancelButton ? null : (
                      <button type="button" className={cancelClassName} data-bs-dismiss="modal">
                        {cancelTextClassName ? (
                          <span className={cancelTextClassName}>{cancelLabel}</span>
                        ) : (
                          cancelLabel
                        )}
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    {props.hideCancelButton ? null : (
                      <button type="button" className={cancelClassName} data-bs-dismiss="modal">
                        {cancelTextClassName ? (
                          <span className={cancelTextClassName}>{cancelLabel}</span>
                        ) : (
                          cancelLabel
                        )}
                      </button>
                    )}
                    {props.hideOkButton ? null : (
                      <button
                        disabled={props.disableOk}
                        type="button"
                        onClick={onOk}
                        className={okClassName}
                      >
                        {okTextClassName ? (
                          <span className={okTextClassName}>{okLabel}</span>
                        ) : (
                          okLabel
                        )}
                      </button>
                    )}
                  </>
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
