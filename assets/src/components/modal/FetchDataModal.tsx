import React, { useEffect, useRef, useState } from 'react';
import { Maybe } from 'tsmonad';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { lockScroll, unlockScroll } from 'components/modal/utils';

interface FetchDataProps<T> {
  title: string;
  onFetchData: () => Promise<T>;
  onDone: (x: T) => void;
  onCancel: () => void;
}

export const FetchDataModal = function <T>({
  title,
  onFetchData,
  onDone,
  onCancel,
}: FetchDataProps<T>) {
  const modal = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<Maybe<string>>(Maybe.nothing());

  useEffect(() => {
    if (modal.current) {
      const currentModal = modal.current;
      (window as any).$(currentModal).modal('show');
      const scrollPosition = lockScroll();

      $(currentModal).on('hidden.bs.modal', () => {
        onCancel();
      });

      return () => {
        (window as any).$(currentModal).modal('hide');
        unlockScroll(scrollPosition);
      };
    }
  }, [modal]);

  useEffect(() => {
    onFetchData()
      .then((result) => {
        onDone(result);
      })
      .catch((message) => setError(Maybe.just(message)));
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium}>Loading...</LoadingSpinner>
  );

  const renderFailed = (errorMsg: string) => (
    <div>
      <div>Failed to fetch values. Close this window and try again.</div>
      <div>Error: ${errorMsg}</div>
    </div>
  );

  return (
    <div ref={modal} className="modal">
      <div className={`modal-dialog modal-dialog-centered modal-md`} role="document">
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title">{title}</h5>
            <button
              type="button"
              className="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
            ></button>
          </div>
          <div className="modal-body">
            {error.caseOf({
              just: (errorMsg) => renderFailed(errorMsg),
              nothing: () => renderLoading(),
            })}
          </div>
          <div className="modal-footer d-flex flex-row">
            <div className="flex-grow-1"></div>
            <button type="button" className="btn btn-link" onClick={onCancel}>
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
