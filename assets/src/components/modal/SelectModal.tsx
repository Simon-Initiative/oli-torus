import React, { useEffect, useRef, useState } from 'react';
import { Maybe } from 'tsmonad';
import { lockScroll, unlockScroll } from 'components/modal/utils';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';

export interface Option {
  value: string | number;
  title: string;
}

type Options<T> = T[];
type OptionsWithSelection<T> = { options: T[]; selectedValue?: string | number };

interface SelectModalProps<T extends Option> {
  title: string;
  description: string;
  onFetchOptions: () => Promise<Options<T> | OptionsWithSelection<T>>;
  onDone: (x: string | number) => void;
  onCancel: () => void;
  additionalControls?: React.ReactNode;
}

export const SelectModal = function <T extends Option>({
  title,
  description,
  onFetchOptions,
  onDone,
  onCancel,
  additionalControls,
}: SelectModalProps<T>) {
  const modal = useRef<HTMLDivElement>(null);
  const [options, setOptions] = useState<Maybe<T[]>>(Maybe.nothing());
  const [error, setError] = useState<Maybe<string>>(Maybe.nothing());
  const [selectedOption, setSelectedOption] = useState<Maybe<T>>(Maybe.nothing());

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
    onFetchOptions()
      .then((result) => {
        // onFetchOptions accepts an array of options or an object that
        // contains options and possibly a selected option's value
        if (Array.isArray(result)) {
          setOptions(Maybe.just(result));
        } else {
          setOptions(Maybe.just(result.options));
          setSelectedOption(
            Maybe.maybe(result.options.find((o) => o.value == result.selectedValue)),
          );
        }
      })
      .catch((message) => setError(Maybe.just(message)));
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium}>Loading...</LoadingSpinner>
  );

  const renderFailed = (errorMsg: string) => (
    <div>
      <div>Failed to load options. Close this window and try again.</div>
      <div>Error: ${errorMsg}</div>
    </div>
  );

  const renderSuccess = (options: T[]) => {
    const renderOption = (o: T) => (
      <option key={o.value} value={o.value}>
        {o.title}
      </option>
    );

    const optionSelect = (
      <select
        className="form-control mr-2"
        value={selectedOption.caseOf({
          just: (s) => `${s.value}`,
          nothing: () => '',
        })}
        onChange={({ target: { value } }) => {
          const item = options.find((o) => `${o.value}` === value);
          if (item) setSelectedOption(Maybe.just(item));
        }}
        style={{ minWidth: '300px' }}
      >
        <option key="none" value="" hidden>
          {description}
        </option>
        {options.map(renderOption)}
      </select>
    );

    return (
      <div className="select-modal">
        <form className="form-inline">
          <label className="sr-only">{description}</label>
          {optionSelect}
        </form>
      </div>
    );
  };

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
              nothing: () =>
                options.caseOf({
                  just: (loaded) => renderSuccess(loaded),
                  nothing: () => renderLoading(),
                }),
            })}
          </div>
          <div className="modal-footer d-flex flex-row">
            {additionalControls}
            <div className="flex-grow-1"></div>
            <button type="button" className="btn btn-link" onClick={onCancel}>
              Cancel
            </button>
            <button
              type="button"
              onClick={() =>
                selectedOption.caseOf({
                  just: (s) => onDone(s.value),
                  nothing: () => {},
                })
              }
              disabled={selectedOption.caseOf({ just: () => false, nothing: () => true })}
              className={`btn btn-primary`}
            >
              Select
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
