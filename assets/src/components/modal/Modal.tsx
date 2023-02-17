import React, { PropsWithChildren, useEffect, useRef } from 'react';
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

export const Modal = (props: PropsWithChildren<ModalProps>) => {
  const { children } = props;
  const modal = useRef<HTMLDivElement>(null);

  const okLabel = props.okLabel !== undefined ? props.okLabel : 'Ok';
  const cancelLabel = props.cancelLabel !== undefined ? props.cancelLabel : 'Cancel';
  const okClassName = props.okClassName !== undefined ? props.okClassName : 'primary';
  const size = props.size || 'lg';

  useEffect(() => {
    if (modal.current) {
      const currentModal = modal.current;

      (window as any).$(currentModal).modal('show');

      $(currentModal).on('hidden.bs.modal', (e) => {
        onCancel(e);
      });

      return () => {
        (window as any).$(currentModal).modal('hide');
      };
    }
  }, []);

  const onCancel = (e: any) => {
    e.preventDefault();
    if (props.onCancel) props.onCancel();
  };

  const onOk = (e: any) => {
    e.preventDefault();
    if (props.onOk) props.onOk();
  };

  return (
    <div
      ref={modal}
      className={classNames(
        'modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto',
      )}
      data-bs-backdrop={props.backdrop}
      data-bs-keyboard={valueOr(props.keyboard, true)}
      tabIndex={-1}
      aria-labelledby={`${props.title} modal`}
      aria-hidden="true"
    >
      <div className={`modal-dialog modal-${size} relative w-auto pointer-events-none`}>
        <div className="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none text-current">
          <div className="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
            <h5 className="text-xl font-medium leading-normal text-gray-800" id="exampleModalLabel">
              {props.title}
            </h5>
            <button
              type="button"
              className="btn-close box-content w-4 h-4 p-1 text-black border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:text-black hover:opacity-75 hover:no-underline"
              data-bs-dismiss="modal"
              aria-label="Close"
            ></button>
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
