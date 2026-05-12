import React, { useEffect, useMemo, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import type { OptionItem } from '../janus-fill-blanks/FIBUtils';
import { fibNumericRowsAllValid } from '../janus-fill-blanks/fibNumeric';

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
  const [selectedType, setSelectedType] = useState<'dropdown' | 'input' | 'number'>('dropdown');
  const selectedOption =
    currentSelectedIndex >= 0
      ? finalOptions[currentSelectedIndex]
      : finalOptions.find((opt) => opt.key === selectedKey);

  const isDropdown = selectedOption?.type === 'dropdown';
  const isNumber = selectedOption?.type === 'number';

  const optionValueStrings = useMemo(
    () => (selectedOption?.options ?? []).map((o: { value?: string }) => String(o?.value ?? '')),
    [selectedOption],
  );

  const isValidItem = useMemo(() => {
    if (!selectedOption?.options?.length || !selectedOption?.correct?.length) {
      return false;
    }
    if (isNumber) {
      return fibNumericRowsAllValid(optionValueStrings);
    }
    return true;
  }, [selectedOption, isNumber, optionValueStrings]);

  useEffect(() => {
    setFinalOptions(Options);
  }, [Options]);
  useEffect(() => {
    if (
      finalOptions.length &&
      currentSelectedIndex >= 0 &&
      currentSelectedIndex < finalOptions.length
    ) {
      const current = finalOptions[currentSelectedIndex];

      if (!current || current.key === selectedKey) return;

      if (current) {
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
      }
    }
  }, [currentSelectedIndex, finalOptions]);

  const updateOptionItems = (updatedItems: QuillCustomOptionProps[]) => {
    const updatedOptions = updatedItems.map((item) => {
      return { key: item.text, value: item.text };
    });
    const correctMarkedItems = updatedItems.filter((item) => item.correct).map((item) => item.text);
    const correct = correctMarkedItems[0] || ''; // Primary correct
    const alternateCorrect = correctMarkedItems.slice(1); // All others
    setFinalOptions((prev) =>
      prev.map((opt) =>
        opt.key === selectedKey
          ? {
              ...opt,
              options: updatedOptions,
              correct,
              alternateCorrect,
              type: selectedType,
            }
          : opt,
      ),
    );
  };

  const handleValueChange = (index: number, text: string) => {
    const updated = [...items];
    updated[index].text = text;
    setItems(updated);
    updateOptionItems(updated);
  };

  const toggleSelected = (index: number) => {
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
    const newItem = {
      text: newCorrectAnswer,
      correct: !isDropdown,
      alternateCorrect: newCorrectAnswer,
    };
    const updated = [...items, newItem];
    setItems(updated);
    updateOptionItems(updated);
  };

  const handleTypeChange = (newType: 'dropdown' | 'input' | 'number') => {
    setSelectedType(newType);
    setFinalOptions((prev) =>
      prev.map((opt) => {
        if (opt.key !== selectedKey) return opt;

        const allCorrect = opt.options || [];
        const altCorrect =
          newType === 'input' || newType === 'number'
            ? allCorrect.slice(1).map((item: { value: string }) => item.value)
            : opt.alternateCorrect;
        return {
          ...opt,
          type: newType,
          correct:
            newType === 'input' || newType === 'number' ? allCorrect[0]?.value || '' : opt.correct,
          alternateCorrect: altCorrect,
        };
      }),
    );

    if (newType === 'input' || newType === 'number') {
      const updatedItems = items.map((item) => ({
        ...item,
        correct: true,
      }));
      setItems(updatedItems);
    }
  };

  const modalTitle = isDropdown
    ? 'Drop Down Items'
    : isNumber
    ? 'Number input — Correct answer(s)'
    : 'Input Items - Correct Answer(s)';

  return (
    <React.Fragment>
      {
        <>
          <Modal show={showOptionDailog} onHide={handleOptionDailogClose} style={{ top: '200px' }}>
            <Modal.Header closeButton={true} className="px-8 pb-0">
              <h3 className="modal-title font-bold">{modalTitle}</h3>
            </Modal.Header>
            <Modal.Body className="px-8" style={{ backgroundColor: 'lightgray' }}>
              <div style={{ display: 'flex', marginBottom: '10px', alignItems: 'center' }}>
                <label className="form-label">Select FITB Item</label>
                <select
                  className="form-control"
                  style={{ width: '69%', marginLeft: '13px' }}
                  value={selectedKey}
                  onChange={(e) => {
                    setCurrentSelectedIndex(e.target.selectedIndex);
                  }}
                >
                  {Options.map((option, index) => (
                    <option key={option.key} value={option.key}>
                      {`Blank ${index + 1}`}
                    </option>
                  ))}
                </select>
              </div>
              <div style={{ display: 'flex', marginBottom: '10px', marginLeft: '20px' }}>
                <label className="form-label" style={{ marginRight: '10px', marginLeft: '12px' }}>
                  Input Type
                </label>
                <label style={{ marginRight: '10px' }}>
                  <input
                    type="radio"
                    name="type"
                    value="dropdown"
                    checked={selectedType === 'dropdown'}
                    onChange={() => handleTypeChange('dropdown')}
                  />{' '}
                  Dropdown
                </label>
                <label style={{ marginRight: '10px' }}>
                  <input
                    type="radio"
                    name="type"
                    value="input"
                    checked={selectedType === 'input'}
                    onChange={() => handleTypeChange('input')}
                  />{' '}
                  Input
                </label>
                <label>
                  <input
                    type="radio"
                    name="type"
                    value="number"
                    checked={selectedType === 'number'}
                    onChange={() => handleTypeChange('number')}
                  />{' '}
                  Number
                </label>
              </div>
              <hr></hr>
              <div style={{ width: '100%' }}>
                {items.map((item, index) => (
                  <div
                    key={index}
                    style={{
                      position: 'relative',
                      marginBottom: '8px',
                    }}
                  >
                    <input
                      id={`fib-option-row-${index}`}
                      type="text"
                      className="form-control"
                      placeholder={
                        isDropdown
                          ? `Drop Down Item ${items?.length}`
                          : isNumber
                          ? 'e.g. 1.5 or 1e10'
                          : `Correct answer ${items?.length}`
                      }
                      value={item.text}
                      onChange={(e) => handleValueChange(index, e.target.value)}
                      style={{
                        width: '100%',
                        paddingRight: '70px',
                      }}
                    />

                    <div
                      style={{
                        position: 'absolute',
                        top: '50%',
                        right: '8px',
                        transform: 'translateY(-50%)',
                        display: 'flex',
                        gap: '13px',
                      }}
                    >
                      <button
                        type="button"
                        className={`circle-btn ${item.correct ? 'correct' : ''}`}
                        onClick={() => toggleSelected(index)}
                        disabled={!isDropdown}
                        style={{
                          border: 'none',
                          background: 'transparent',
                          padding: '0',
                          cursor: 'pointer',
                        }}
                      >
                        {item.correct ? (
                          <i
                            style={{ color: '#3B76D3' }}
                            className="fa-solid fa-circle-check fa-lg"
                          ></i>
                        ) : (
                          <i className="fa-regular fa-circle-check fa-lg"></i>
                        )}
                      </button>

                      <button
                        type="button"
                        onClick={() => removeItem(index)}
                        style={{
                          border: 'none',
                          background: 'transparent',
                          padding: '0',
                          cursor: 'pointer',
                        }}
                      >
                        <i className="fa-solid fa-xmark"></i>
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </Modal.Body>
            <Modal.Footer className="px-8 pb-6 flex-row justify-items-stretch">
              <OverlayTrigger
                placement="bottom"
                delay={{ show: 150, hide: 150 }}
                overlay={
                  <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
                    {!isValidItem ? (
                      isDropdown ? (
                        <div>You must mark one option as correct.</div>
                      ) : isNumber ? (
                        <div>Each answer must be a valid number (decimals and scientific notation).</div>
                      ) : (
                        <div>You must have one correct option.</div>
                      )
                    ) : (
                      <div>Save changes</div>
                    )}
                  </Tooltip>
                }
              >
                <button
                  id="btnDelete"
                  className="btn btn-primary flex-grow basis-1"
                  disabled={!isValidItem}
                  onClick={() => {
                    handleOptionSave(finalOptions);
                  }}
                >
                  Update Changes
                </button>
              </OverlayTrigger>

              <button
                type="button"
                className="btn btn-secondary"
                style={{ border: '1px solid gray' }}
                onClick={addItem}
              >
                <i className="fa-solid fa-plus"></i> Add item
              </button>

              <button
                type="button"
                className="btn btn-default"
                style={{ border: '1px solid gray' }}
                onClick={handleOptionDailogClose}
              >
                Cancel
              </button>
            </Modal.Footer>
          </Modal>
        </>
      }
    </React.Fragment>
  );
};
