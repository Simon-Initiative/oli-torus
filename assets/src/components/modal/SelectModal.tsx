import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Maybe } from 'tsmonad';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { lockScroll, unlockScroll } from 'components/modal/utils';
import { SearchIcon } from 'components/misc/icons/Icons';

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
  searchable?: boolean;
  searchPlaceholder?: string;
  searchAriaLabel?: string;
  clearAriaLabel?: string;
  emptySearchMessage?: string;
}

// Selector for focusable elements
const FOCUSABLE_SELECTOR =
  'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export const SelectModal = function <T extends Option>({
  title,
  description,
  onFetchOptions,
  onDone,
  onCancel,
  additionalControls,
  searchable = false,
  searchPlaceholder = 'Search',
  searchAriaLabel = 'Search options',
  clearAriaLabel = 'Clear selection',
  emptySearchMessage = 'No options match your search.',
}: SelectModalProps<T>) {
  const modal = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);
  const modalId = useRef(`select-modal-${Math.random().toString(36).substr(2, 9)}`);
  const selectId = `${modalId.current}-select`;
  const searchInputId = `${modalId.current}-search`;
  const listboxId = `${modalId.current}-options`;
  const [options, setOptions] = useState<Maybe<T[]>>(Maybe.nothing());
  const [error, setError] = useState<Maybe<string>>(Maybe.nothing());
  const [selectedOption, setSelectedOption] = useState<Maybe<T>>(Maybe.nothing());
  const [searchTerm, setSearchTerm] = useState('');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const hasSearchSelection = selectedOption.caseOf({ just: () => true, nothing: () => false });

  // Focus trap handler
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (e.key !== 'Tab' || !modal.current) return;

    const focusableElements = modal.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
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
  }, []);

  useEffect(() => {
    if (modal.current) {
      const currentModal = modal.current;

      // Save the currently focused element to restore later
      previousActiveElement.current = document.activeElement as HTMLElement;

      (window as any).$(currentModal).modal('show');
      const scrollPosition = lockScroll();

      // Focus the first focusable element when modal opens
      $(currentModal).on('shown.bs.modal', () => {
        const focusableElements = currentModal.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
        if (focusableElements.length > 0) {
          focusableElements[0].focus();
        }
      });

      $(currentModal).on('hidden.bs.modal', () => {
        onCancel();
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
        unlockScroll(scrollPosition);
      };
    }
  }, [modal, handleKeyDown]);

  useEffect(() => {
    onFetchOptions()
      .then((result) => {
        // onFetchOptions accepts an array of options or an object that
        // contains options and possibly a selected option's value
        if (Array.isArray(result)) {
          setOptions(Maybe.just(result));
        } else {
          setOptions(Maybe.just(result.options));
          const selected = Maybe.maybe(result.options.find((o) => o.value == result.selectedValue));
          setSelectedOption(selected);
          selected.caseOf({
            just: (s) => setSearchTerm(s.title),
            nothing: () => {},
          });
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
    const normalizedSearchTerm = searchTerm.trim().toLocaleLowerCase();
    const filteredOptions =
      searchable && normalizedSearchTerm !== ''
        ? options.filter((o) => o.title.toLocaleLowerCase().includes(normalizedSearchTerm))
        : options;

    const renderNativeOption = (o: T) => (
      <option key={o.value} value={o.value}>
        {o.title}
      </option>
    );

    const nativeSelect = (
      <select
        id={selectId}
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
        {options.map(renderNativeOption)}
      </select>
    );

    const selectSearchableOption = (o: T) => {
      setSelectedOption(Maybe.just(o));
      setSearchTerm(o.title);
      setIsSearchOpen(false);
    };

    const renderSearchableOption = (o: T) => {
      const selected = selectedOption.caseOf({
        just: (s) => `${s.value}` === `${o.value}`,
        nothing: () => false,
      });

      return (
        <button
          key={o.value}
          id={`${listboxId}-${o.value}`}
          type="button"
          role="option"
          aria-selected={selected}
          className={`dropdown-item w-100 overflow-hidden text-truncate text-left dark:text-gray-100 dark:hover:bg-gray-700${
            selected ? ' active' : ''
          }`}
          title={o.title}
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => selectSearchableOption(o)}
        >
          {o.title}
        </button>
      );
    };

    const searchableSelect = (
      <div
        className="w-100"
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
            setIsSearchOpen(false);
          }
        }}
      >
        <label className="sr-only" htmlFor={searchInputId}>
          {description}
        </label>
        <div className="d-flex w-100 align-items-center rounded border border-gray-300 bg-white dark:border-gray-600 dark:bg-gray-800">
          {!hasSearchSelection && (
            <span className="d-inline-flex align-items-center pl-3 pr-2 text-Text-text-low-alpha">
              <SearchIcon width={18} height={18} />
            </span>
          )}
          <input
            id={searchInputId}
            type="text"
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={isSearchOpen}
            aria-controls={listboxId}
            className="form-control flex-grow-1 border-0 bg-transparent shadow-none"
            placeholder={searchPlaceholder}
            aria-label={searchAriaLabel}
            value={searchTerm}
            onClick={() => setIsSearchOpen(true)}
            onFocus={() => setIsSearchOpen(true)}
            onChange={(event) => {
              setSearchTerm(event.target.value);
              setSelectedOption(Maybe.nothing());
              setIsSearchOpen(true);
            }}
            style={{ border: 0, boxShadow: 'none', minWidth: 0 }}
          />
          {hasSearchSelection && (
            <button
              type="button"
              className="btn btn-link px-3 py-0 text-Text-text-low-alpha"
              aria-label={clearAriaLabel}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => {
                setSelectedOption(Maybe.nothing());
                setSearchTerm('');
                setIsSearchOpen(true);
              }}
              style={{
                cursor: 'pointer',
                textDecoration: 'none',
              }}
            >
              &times;
            </button>
          )}
        </div>
        {isSearchOpen && (
          <>
            <div
              id={listboxId}
              role="listbox"
              className="max-h-96 w-100 overflow-x-hidden overflow-y-auto rounded border border-gray-300 bg-white p-0 shadow-sm dark:border-gray-600 dark:bg-gray-800"
            >
              {filteredOptions.map(renderSearchableOption)}
            </div>
            {filteredOptions.length === 0 && (
              <div className="text-muted mt-2" role="status">
                {emptySearchMessage}
              </div>
            )}
          </>
        )}
      </div>
    );

    return (
      <div className="select-modal">
        <form
          className={searchable ? 'form-inline flex-column align-items-stretch' : 'form-inline'}
          onSubmit={(event) => event.preventDefault()}
        >
          {searchable ? (
            searchableSelect
          ) : (
            <>
              <label className="sr-only" htmlFor={selectId}>
                {description}
              </label>
              {nativeSelect}
            </>
          )}
        </form>
      </div>
    );
  };

  const titleId = `${modalId.current}-title`;

  return (
    <div ref={modal} className="modal" role="dialog" aria-modal="true" aria-labelledby={titleId}>
      <div className={`modal-dialog modal-dialog-centered ${searchable ? 'modal-lg' : 'modal-md'}`}>
        <div className="modal-content dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700">
          <div className="modal-header dark:border-gray-700">
            <h5 className="modal-title" id={titleId}>
              {title}
            </h5>
            <button
              type="button"
              className="box-content w-4 h-4 p-1 border-none rounded-none opacity-50 hover:text-black hover:opacity-75 dark:hover:text-white hover:no-underline focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 dark:text-gray-400"
              data-bs-dismiss="modal"
              aria-label="Close"
            >
              <i className="fa-solid fa-xmark fa-xl"></i>
            </button>
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
          <div className="modal-footer d-flex flex-row dark:border-gray-700">
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
