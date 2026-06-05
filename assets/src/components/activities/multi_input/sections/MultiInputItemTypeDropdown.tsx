import React from 'react';
import {
  MultiInputQuestionType,
  multiInputQuestionOptionGroups,
  multiInputQuestionOptions,
} from 'components/activities/multi_input/utils';
import { ChevronDown } from 'components/misc/icons/Icons';

type Props = {
  editMode: boolean;
  onChange: (questionType: MultiInputQuestionType) => void;
  selected: MultiInputQuestionType;
};

const allOptions = multiInputQuestionOptionGroups.flatMap(({ options }) => options);

const optionFor = (value: MultiInputQuestionType) =>
  allOptions.find((option) => option.value === value) ?? allOptions[0];

const optionClass = (isSelected: boolean, isActive: boolean) =>
  [
    'flex w-full flex-col rounded border-0 px-3 py-2 text-left text-body-color dark:text-body-color-dark',
    isSelected ? 'bg-blue-100 dark:bg-blue-900' : 'bg-white dark:bg-body-dark',
    isActive && !isSelected ? 'bg-blue-50 dark:bg-gray-800' : '',
    'hover:bg-blue-50 focus:bg-blue-50 focus:outline-none dark:hover:bg-gray-800 dark:focus:bg-gray-800',
  ]
    .filter(Boolean)
    .join(' ');

export const MultiInputItemTypeDropdown: React.FC<Props> = ({ editMode, selected, onChange }) => {
  const [isOpen, setIsOpen] = React.useState(false);
  const [activeValue, setActiveValue] = React.useState<MultiInputQuestionType>(selected);
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const listboxId = React.useRef(`multi-input-item-type-${Math.random().toString(36).slice(2)}`);
  const selectedOption = optionFor(selected);

  React.useEffect(() => {
    setActiveValue(selected);
  }, [selected]);

  React.useEffect(() => {
    if (!isOpen) return;

    const closeOnOutsideClick = (event: MouseEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', closeOnOutsideClick);
    return () => document.removeEventListener('mousedown', closeOnOutsideClick);
  }, [isOpen]);

  const selectOption = (value: MultiInputQuestionType) => {
    onChange(value);
    setIsOpen(false);
  };

  const moveActiveOption = (direction: 1 | -1) => {
    const currentIndex = multiInputQuestionOptions.findIndex(({ value }) => value === activeValue);
    const nextIndex =
      (currentIndex + direction + multiInputQuestionOptions.length) %
      multiInputQuestionOptions.length;
    setActiveValue(multiInputQuestionOptions[nextIndex].value);
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (!editMode) return;

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (!isOpen) {
          setIsOpen(true);
        } else {
          moveActiveOption(1);
        }
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (!isOpen) {
          setIsOpen(true);
        } else {
          moveActiveOption(-1);
        }
        break;
      case 'Enter':
      case ' ':
        event.preventDefault();
        if (isOpen) {
          selectOption(activeValue);
        } else {
          setIsOpen(true);
        }
        break;
      case 'Escape':
        setIsOpen(false);
        break;
    }
  };

  return (
    <div
      ref={containerRef}
      className="relative ml-1 w-[34rem] max-w-[calc(100vw-3rem)]"
      onKeyDown={handleKeyDown}
    >
      <button
        type="button"
        className="flex w-full items-center justify-between gap-3 rounded border border-gray-300 bg-white px-3 py-2 text-left text-body-color shadow-sm hover:border-gray-400 focus:border-blue-400 focus:outline-none focus:ring-2 focus:ring-blue-100 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:opacity-75 dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark dark:hover:border-gray-500 dark:focus:border-blue-500 dark:focus:ring-blue-900 dark:disabled:bg-gray-800"
        disabled={!editMode}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={listboxId.current}
        aria-activedescendant={isOpen ? `${listboxId.current}-${activeValue}` : undefined}
        onClick={() => editMode && setIsOpen((open) => !open)}
      >
        <span className="flex min-w-0 flex-col">
          <span className="font-semibold leading-tight">{selectedOption.displayValue}</span>
          <span className="mt-0.5 text-xs leading-snug text-gray-600 dark:text-gray-300">
            Example: {selectedOption.example}
          </span>
        </span>
        <ChevronDown className="h-4 w-4 flex-shrink-0 text-gray-600 dark:text-gray-300" />
      </button>

      {isOpen && (
        <div
          id={listboxId.current}
          className="absolute right-0 z-50 mt-1 max-h-96 w-full overflow-y-auto rounded-md border border-gray-300 bg-white p-2 shadow-xl dark:border-gray-600 dark:bg-body-dark"
          role="listbox"
          aria-label="Input type"
          tabIndex={-1}
        >
          {multiInputQuestionOptionGroups.map((group) => (
            <div
              className="border-t border-gray-200 pt-2 first:border-t-0 first:pt-0 dark:border-gray-700"
              key={group.label}
            >
              <div className="mb-1 rounded bg-blue-900 px-2 py-1.5 text-sm font-bold uppercase tracking-normal text-white shadow-sm dark:bg-blue-700 dark:text-white">
                {group.label}
              </div>
              {group.options.map((option) => {
                const isSelected = option.value === selected;
                const isActive = option.value === activeValue;

                return (
                  <button
                    type="button"
                    key={option.value}
                    id={`${listboxId.current}-${option.value}`}
                    role="option"
                    aria-selected={isSelected}
                    className={optionClass(isSelected, isActive)}
                    onMouseEnter={() => setActiveValue(option.value)}
                    onClick={() => selectOption(option.value)}
                  >
                    <span className="flex items-baseline justify-between gap-3">
                      <span className="font-semibold leading-snug">{option.displayValue}</span>
                      <span className="min-w-0 flex-shrink break-words text-right font-mono text-xs leading-snug text-gray-700 dark:text-gray-300">
                        {option.example}
                      </span>
                    </span>
                    <span className="mt-0.5 text-xs leading-snug text-gray-600 dark:text-gray-300">
                      {option.description}
                    </span>
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
