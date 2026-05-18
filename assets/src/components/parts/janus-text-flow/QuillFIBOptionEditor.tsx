import React, { useEffect, useMemo, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import type { OptionItem } from '../janus-fill-blanks/FIBUtils';
import {
  fibNumericRowsAllValid,
  fibTolerancePercentAuthoringValid,
} from '../janus-fill-blanks/fibNumeric';
import './QuillFIBOptionEditor.scss';

export type { OptionItem } from '../janus-fill-blanks/FIBUtils';

export interface QuillCustomOptionProps {
  text: string;
  correct: boolean;
}

interface QuillFIBOptionEditorProps {
  handleOptionSave: (options: Array<OptionItem>) => void;
  handleOptionDailogClose: () => void;
  showOptionDailog?: boolean;
  Options: OptionItem[];
  selectedIndex: number;
}

export const QuillFIBOptionEditor: React.FC<QuillFIBOptionEditorProps> = ({
  handleOptionSave,
  showOptionDailog,
  handleOptionDailogClose,
  Options,
  selectedIndex,
}) => {
  const [selectedKey, setSelectedKey] = useState<string>('');
  const [currentSelectedIndex, setCurrentSelectedIndex] = useState<number>(selectedIndex);
  const [items, setItems] = useState<QuillCustomOptionProps[]>([]);
  const [finalOptions, setFinalOptions] = useState<OptionItem[]>([]);
  const [selectedType, setSelectedType] = useState<'dropdown' | 'input' | 'number'>(() => {
    const opt = Options[selectedIndex >= 0 ? selectedIndex : 0];
    if (opt?.type === 'number') return 'number';
    if (opt?.type === 'input') return 'input';
    return 'dropdown';
  });
  const [toleranceDraft, setToleranceDraft] = useState<string>('');
  const selectedOption =
    currentSelectedIndex >= 0
      ? finalOptions[currentSelectedIndex]
      : finalOptions.find((opt) => opt.key === selectedKey);

  const isDropdown = selectedOption?.type === 'dropdown';
  const isNumber = selectedOption?.type === 'number';

  const selectValue = Options[currentSelectedIndex]?.key ?? selectedKey ?? '';

  const optionValueStrings = useMemo(
    () => (selectedOption?.options ?? []).map((o: { value?: string }) => String(o?.value ?? '')),
    [selectedOption],
  );

  const isValidItem = useMemo(() => {
    if (!selectedOption?.options?.length || !selectedOption?.correct?.length) {
      return false;
    }
    if (isNumber) {
      if (!fibNumericRowsAllValid(optionValueStrings)) return false;
      if (!fibTolerancePercentAuthoringValid(selectedOption.tolerancePercent)) return false;
      return true;
    }
    return true;
  }, [selectedOption, isNumber, optionValueStrings]);

  /** Number type: existing row text is not a valid FITB numeric literal (e.g. after switching from dropdown). */
  const numberRowFormatInvalid = useMemo(
    () => isNumber && optionValueStrings.length > 0 && !fibNumericRowsAllValid(optionValueStrings),
    [isNumber, optionValueStrings],
  );

  const modalTitle = useMemo(() => {
    switch (selectedType) {
      case 'dropdown':
        return 'Drop Down Items';
      case 'input':
        return 'Text Input Items - Correct Answer(s)';
      case 'number':
        return 'Number Input Items - Correct Answer(s)';
      default:
        return 'Configure FITB';
    }
  }, [selectedType]);

  useEffect(() => {
    setFinalOptions(Options);
  }, [Options]);
  useEffect(() => {
    if (
      !finalOptions.length ||
      currentSelectedIndex < 0 ||
      currentSelectedIndex >= finalOptions.length
    ) {
      return;
    }
    const current = finalOptions[currentSelectedIndex];
    if (!current) return;

    if (current.key !== selectedKey) {
      setSelectedKey(current.key);
    }

    setSelectedType(current.type);

    setItems(
      current.options.map((opt) => ({
        text: opt.value,
        correct:
          current.type === 'dropdown'
            ? current.correct === opt.value || current.alternateCorrect?.includes(opt.value)
            : true,
        alternateCorrect: '',
      })),
    );
  }, [currentSelectedIndex, finalOptions]);

  useEffect(() => {
    const cur = finalOptions[currentSelectedIndex];
    const v = cur?.tolerancePercent;
    setToleranceDraft(v != null && Number.isFinite(v) ? String(v) : '');
  }, [currentSelectedIndex, selectedKey, finalOptions]);

  const handleTolerancePercentChange = (raw: string) => {
    setToleranceDraft(raw);
    const trimmed = raw.trim();
    const n = parseFloat(trimmed);
    setFinalOptions((prev) => {
      const key = prev[currentSelectedIndex]?.key ?? selectedKey;
      return prev.map((opt) => {
        if (opt.key !== key) return opt;
        if (trimmed === '' || Number.isNaN(n) || n < 0) {
          const { tolerancePercent: _tp, ...rest } = opt;
          return rest as OptionItem;
        }
        return { ...opt, tolerancePercent: n };
      });
    });
  };

  const updateOptionItems = (updatedItems: QuillCustomOptionProps[]) => {
    const updatedOptions = updatedItems.map((item) => {
      return { key: item.text, value: item.text };
    });
    const correctMarkedItems = updatedItems.filter((item) => item.correct).map((item) => item.text);
    const correct = correctMarkedItems[0] || '';
    const alternateCorrect = correctMarkedItems.slice(1);
    setFinalOptions((prev) => {
      const key = prev[currentSelectedIndex]?.key ?? selectedKey;
      return prev.map((opt) =>
        opt.key === key
          ? {
              ...opt,
              options: updatedOptions,
              correct,
              alternateCorrect,
              type: selectedType,
            }
          : opt,
      );
    });
  };

  const handleValueChange = (index: number, text: string) => {
    const updated = [...items];
    updated[index].text = text;
    setItems(updated);
    updateOptionItems(updated);
  };

  const handleCorrectToggle = (index: number) => {
    if (!isDropdown) return;
    const updated = items.map((item, i) =>
      i === index ? { ...item, correct: !item.correct } : item,
    );
    setItems(updated);
    updateOptionItems(updated);
  };

  const removeItem = (index: number) => {
    const updated = items.filter((_, i) => i !== index);

    const adjusted =
      selectedType === 'input' || selectedType === 'number'
        ? updated.map((item) => ({ ...item, correct: true }))
        : updated;

    setItems(adjusted);
    updateOptionItems(adjusted);
  };

  const addItem = () => {
    const newCorrectAnswer = isDropdown
      ? `Drop Down Item ${items.length + 1}`
      : isNumber
      ? `${items.length + 1}`
      : `Correct Answer ${items.length + 1}`;
    const newItem: QuillCustomOptionProps = {
      text: newCorrectAnswer,
      correct: !isDropdown,
    };
    const updated = [...items, newItem];
    setItems(updated);
    updateOptionItems(updated);
  };

  const handleTypeChange = (newType: 'dropdown' | 'input' | 'number') => {
    setSelectedType(newType);
    setFinalOptions((prev) => {
      const key = prev[currentSelectedIndex]?.key ?? selectedKey;
      return prev.map((opt) => {
        if (opt.key !== key) return opt;

        const allCorrect = opt.options || [];

        if (newType === 'number') {
          const optionsRows = (opt.options || []).map((item: { value?: string; key?: string }) => {
            const v = String(item?.value ?? item?.key ?? '');
            return { key: v, value: v };
          });
          const correct = optionsRows[0]?.value || '';
          const alternateCorrect = optionsRows.slice(1).map((o) => o.value);
          return {
            ...opt,
            type: 'number',
            options: optionsRows,
            correct,
            alternateCorrect,
          } as OptionItem;
        }

        const altCorrect =
          newType === 'input'
            ? allCorrect.slice(1).map((item: { value: string }) => item.value)
            : opt.alternateCorrect;
        const base: OptionItem = {
          ...opt,
          type: newType,
          correct: newType === 'input' ? allCorrect[0]?.value || '' : opt.correct,
          alternateCorrect: altCorrect,
        };
        const { tolerancePercent: _t, ...rest } = base;
        return rest as OptionItem;
      });
    });

    if (newType === 'input' || newType === 'number') {
      const updatedItems = items.map((item) => ({
        ...item,
        correct: true,
      }));
      setItems(updatedItems);
    }
  };

  const answersSectionTitle = isDropdown ? 'Dropdown Options' : 'Accepted Answer(s)';
  const answersSectionSubtext = isDropdown
    ? 'Add options and toggle the switch for correct ones.'
    : 'Add values that will be graded as correct.';
  const addButtonLabel = isDropdown ? 'Add new option' : 'Add alternative answer';

  const typeCard = (type: 'dropdown' | 'input' | 'number', iconClass: string, caption: string) => {
    const selected = selectedType === type;
    return (
      <label
        key={type}
        className={`quill-fib-option-editor__type-card${
          selected ? ' quill-fib-option-editor__type-card--selected' : ''
        }`}
      >
        <input
          type="radio"
          name="fib-input-type"
          value={type}
          checked={selected}
          onChange={() => handleTypeChange(type)}
          className="quill-fib-option-editor__type-radio"
        />
        <i
          className={`quill-fib-option-editor__type-icon fa-solid ${iconClass}`}
          aria-hidden={true}
        />
        <span className="quill-fib-option-editor__type-caption">{caption}</span>
      </label>
    );
  };

  return (
    <React.Fragment>
      <>
        <Modal show={showOptionDailog} onHide={handleOptionDailogClose}>
          <Modal.Header closeButton={true} className="px-4 pb-2 pt-3 border-bottom bg-light">
            <h3 className="modal-title h5 mb-0 fw-semibold text-dark">{modalTitle}</h3>
          </Modal.Header>
          <Modal.Body className="p-0 bg-white">
            <div className="quill-fib-option-editor" style={{ padding: '24px' }}>
              <div className="quill-fib-option-editor__section">
                <label className="quill-fib-option-editor__label" htmlFor="fib-blank-select">
                  Select FITB Item
                </label>
                <div className="quill-fib-option-editor__select-wrap">
                  <select
                    id="fib-blank-select"
                    className="quill-fib-option-editor__select"
                    value={selectValue}
                    title="Choose which blank to configure"
                    onChange={(e) => {
                      const idx = (e.target as HTMLSelectElement).selectedIndex;
                      setCurrentSelectedIndex(idx);
                      if (Options[idx]) {
                        setSelectedKey(Options[idx].key);
                      }
                    }}
                  >
                    {Options.map((option, index) => (
                      <option key={option.key} value={option.key}>
                        {`Blank ${index + 1}`}
                      </option>
                    ))}
                  </select>
                  <span className="quill-fib-option-editor__select-chevron" aria-hidden={true}>
                    <i className="fa-solid fa-chevron-down" />
                  </span>
                </div>
              </div>

              <div className="quill-fib-option-editor__section">
                <label className="quill-fib-option-editor__label quill-fib-option-editor__label--sub">
                  Input Type
                </label>
                <div
                  className="quill-fib-option-editor__type-grid"
                  role="radiogroup"
                  aria-label="Input type"
                >
                  {typeCard('dropdown', 'fa-list-ul', 'Dropdown')}
                  {typeCard('input', 'fa-keyboard', 'Input Text')}
                  {typeCard('number', 'fa-arrow-up-9-1', 'Number Input')}
                </div>
              </div>

              <div
                className={`quill-fib-option-editor__tolerance${
                  isNumber ? '' : ' quill-fib-option-editor__tolerance--hidden'
                }`}
                aria-hidden={!isNumber}
              >
                <label
                  className="quill-fib-option-editor__tolerance-title"
                  htmlFor="fib-num-tolerance"
                >
                  Percent Tolerance <span>(Optional)</span>
                </label>
                <p id="fib-num-tolerance-help" className="quill-fib-option-editor__tolerance-help">
                  Allows a variance of ±% from the values. Leave blank for an exact match.
                </p>
                <div className="quill-fib-option-editor__tolerance-input-wrap">
                  <span className="quill-fib-option-editor__tolerance-affix quill-fib-option-editor__tolerance-affix--left">
                    ±
                  </span>
                  <input
                    id="fib-num-tolerance"
                    type="text"
                    className="quill-fib-option-editor__tolerance-input"
                    placeholder="e.g. 5"
                    value={toleranceDraft}
                    onChange={(e) => handleTolerancePercentChange(e.target.value)}
                    aria-describedby="fib-num-tolerance-help"
                  />
                  <span className="quill-fib-option-editor__tolerance-affix quill-fib-option-editor__tolerance-affix--right">
                    %
                  </span>
                </div>
              </div>

              <div className="quill-fib-option-editor__section" style={{ marginBottom: 0 }}>
                <div className="quill-fib-option-editor__answers-header">
                  <div>
                    <label
                      className="quill-fib-option-editor__label"
                      style={{ marginBottom: '4px' }}
                    >
                      {answersSectionTitle}
                    </label>
                    <p className="quill-fib-option-editor__answers-subtext">
                      {answersSectionSubtext}
                    </p>
                  </div>
                </div>

                {numberRowFormatInvalid ? (
                  <div
                    className="quill-fib-option-editor__number-format-warning"
                    role="alert"
                  >
                    Enter a valid number for each accepted answer. Decimals and scientific notation
                    (e.g. 1e10) are allowed.
                  </div>
                ) : null}

                <div>
                  {items.map((item, index) => {
                    const rowLocked = !isDropdown;
                    const statusId = `fib-option-status-${index}`;
                    return (
                      <div className="quill-fib-option-editor__answer-row" key={index}>
                        <div
                          className={
                            'quill-fib-option-editor__answer-row-inner' +
                            (item.correct
                              ? ' quill-fib-option-editor__answer-row-inner--correct'
                              : ' quill-fib-option-editor__answer-row-inner--neutral')
                          }
                        >
                          {isDropdown ? (
                            <span
                              className="quill-fib-option-editor__answer-grip"
                              aria-hidden={true}
                            >
                              <i className="fa-solid fa-grip-vertical" />
                            </span>
                          ) : null}
                          <input
                            id={`fib-option-row-${index}`}
                            type={isNumber ? 'number' : 'text'}
                            step={isNumber ? 1 : undefined}
                            className="quill-fib-option-editor__answer-input quill-fib-option-editor__answer-input--in-row"
                            placeholder={
                              isDropdown
                                ? `Drop down item ${items?.length}`
                                : isNumber
                                ? 'e.g. 1.5 or 1e10'
                                : `Correct answer ${items?.length}`
                            }
                            value={item.text}
                            onChange={(e) => handleValueChange(index, e.target.value)}
                            aria-describedby={statusId}
                          />
                          <div className="quill-fib-option-editor__answer-meta">
                            <span
                              id={statusId}
                              className={
                                'quill-fib-option-editor__answer-status' +
                                (item.correct
                                  ? ' quill-fib-option-editor__answer-status--correct'
                                  : ' quill-fib-option-editor__answer-status--incorrect')
                              }
                            >
                              {item.correct ? 'Correct' : 'Incorrect'}
                            </span>
                            <label
                              className={
                                'quill-fib-option-editor__answer-toggle' +
                                (rowLocked ? ' quill-fib-option-editor__answer-toggle--locked' : '')
                              }
                            >
                              <input
                                type="checkbox"
                                className="quill-fib-option-editor__answer-toggle-input"
                                checked={item.correct}
                                disabled={rowLocked}
                                onChange={() => handleCorrectToggle(index)}
                                aria-label={
                                  rowLocked
                                    ? 'Correct (all accepted answers are graded as correct)'
                                    : item.correct
                                    ? 'Mark as incorrect'
                                    : 'Mark as correct'
                                }
                              />
                              <span
                                className="quill-fib-option-editor__answer-toggle-track"
                                aria-hidden={true}
                              />
                            </label>
                          </div>
                        </div>
                        <button
                          type="button"
                          className="quill-fib-option-editor__answer-trash"
                          onClick={() => removeItem(index)}
                          aria-label={`Remove answer ${index + 1}`}
                        >
                          <i className="fa-solid fa-trash-can" aria-hidden={true} />
                        </button>
                      </div>
                    );
                  })}
                </div>

                <button
                  type="button"
                  className="quill-fib-option-editor__add-alt"
                  onClick={addItem}
                >
                  <i className="fa-solid fa-plus" style={{ fontSize: '12px' }} aria-hidden={true} />
                  {addButtonLabel}
                </button>
              </div>
            </div>
          </Modal.Body>
          <Modal.Footer className="p-0 border-0 w-100 d-block">
            <div className="quill-fib-option-editor__footer">
              <OverlayTrigger
                placement="top"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="fib-option-save-tooltip" style={{ fontSize: '12px' }}>
                    {!isValidItem ? (
                      isDropdown ? (
                        <div>Mark at least one dropdown option as correct.</div>
                      ) : isNumber ? (
                        !selectedOption?.options?.length || !selectedOption?.correct?.length ? (
                          <div>Enter at least one accepted answer.</div>
                        ) : numberRowFormatInvalid ? (
                          <div>
                            Enter a valid number for each accepted answer. Decimals and scientific
                            notation (e.g. 1e10) are allowed.
                          </div>
                        ) : (
                          <div>
                            Tolerance must be empty or a non-negative percent.
                          </div>
                        )
                      ) : (
                        <div>Enter at least one accepted answer.</div>
                      )
                    ) : (
                      <div>Save changes</div>
                    )}
                  </Tooltip>
                }
              >
                <span className="d-inline-block">
                  <button
                    type="button"
                    id="fib-option-save"
                    className="quill-fib-option-editor__btn-primary"
                    disabled={!isValidItem}
                    onClick={() => {
                      handleOptionSave(finalOptions);
                    }}
                  >
                    Update Changes
                  </button>
                </span>
              </OverlayTrigger>
              <button
                type="button"
                className="quill-fib-option-editor__btn-secondary"
                onClick={handleOptionDailogClose}
              >
                Cancel
              </button>
            </div>
          </Modal.Footer>
        </Modal>
      </>
    </React.Fragment>
  );
};
