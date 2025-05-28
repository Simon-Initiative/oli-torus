import React, { useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';

export interface QuillCustomOptionProps {
  text: string;
  correct: boolean;
}

export interface OptionItem {
  key: string;
  options: any[];
  type: 'dropdown' | 'input';
  correct: string;
  alternateCorrect: string[];
}

interface QuillCustomOptionEditorProps {
  handleOptionDetailsSave: (options: Array<OptionItem>) => void;
  handleOptionDailogClose: () => void;
  showOptionDailog?: boolean;
  Options: OptionItem[];
  selectedIndex: number;
}

export const QuillCustomOptionEditor: React.FC<QuillCustomOptionEditorProps> = ({
  handleOptionDetailsSave,
  showOptionDailog,
  handleOptionDailogClose,
  Options,
  selectedIndex,
}) => {
  const [selectedKey, setSelectedKey] = useState<string>('');
  const [currentSelectedIndex, setCurrentSelectedIndex] = useState<number>(selectedIndex);
  const [items, setItems] = useState<QuillCustomOptionProps[]>([]);
  const [finalOptions, setFinalOptions] = useState<OptionItem[]>([]);
  const [selectedType, setSelectedType] = useState<'dropdown' | 'input'>('dropdown');
  const selectedOption =
    currentSelectedIndex >= 0
      ? finalOptions[currentSelectedIndex]
      : finalOptions.find((opt) => opt.key === selectedKey);

  const isDropdown = selectedOption?.type === 'dropdown';
  const isValidItem = selectedOption?.options?.length && selectedOption?.correct?.length;
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

      if (!current || current.key === selectedKey) return; // 🛑 Prevent overwrite unless it's a real change

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

    // If type is 'input', all remaining items are correct
    const adjusted =
      selectedType === 'input' ? updated.map((item) => ({ ...item, correct: true })) : updated;

    setItems(adjusted);
    updateOptionItems(adjusted);
  };

  const addItem = () => {
    const newCorrectAnswer = `${isDropdown ? 'Drop Down Item' : 'Correct Answer'} ${
      items.length + 1
    }`;
    const newItem = {
      text: newCorrectAnswer,
      correct: !isDropdown,
      alternateCorrect: newCorrectAnswer,
    };
    const updated = [...items, newItem];
    setItems(updated);
    updateOptionItems(updated);
  };

  const handleTypeChange = (newType: 'dropdown' | 'input') => {
    setSelectedType(newType);
    setFinalOptions((prev) =>
      prev.map((opt) => {
        if (opt.key !== selectedKey) return opt;

        const allCorrect = opt.options || [];
        const altCorrect =
          newType === 'input' ? allCorrect.slice(1).map((item: any) => item.value) : [];
        return {
          ...opt,
          type: newType,
          correct: newType === 'input' ? allCorrect[0].value || '' : '',
          alternateCorrect: altCorrect,
        };
      }),
    );

    // Mark all current items as correct when switching to input
    if (newType === 'input') {
      const updatedItems = items.map((item) => ({
        ...item,
        correct: true,
      }));
      setItems(updatedItems);
    }
  };

  return (
    <React.Fragment>
      {
        <>
          <Modal show={showOptionDailog} onHide={handleOptionDailogClose} style={{ top: '200px' }}>
            <Modal.Header closeButton={true} className="px-8 pb-0">
              <h3 className="modal-title font-bold">
                {isDropdown ? 'Drop Down Items' : 'Input Items - Correct Answer(s)'}
              </h3>
            </Modal.Header>
            <Modal.Body className="px-8" style={{ backgroundColor: 'lightgray' }}>
              <div style={{ display: 'flex', marginBottom: '10px', alignItems: 'center' }}>
                <label className="form-label">Select FIB Item</label>
                <select
                  className="form-control"
                  style={{ width: '71%', marginLeft: '13px' }}
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
                    onChange={(e) => handleTypeChange('dropdown')}
                  />{' '}
                  Dropdown
                </label>
                <label>
                  <input
                    type="radio"
                    name="type"
                    value="input"
                    checked={selectedType === 'input'}
                    onChange={(e) => handleTypeChange('input')}
                  />{' '}
                  Input
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
                    {/* Input field with padding for buttons */}
                    <input
                      id="url-text-input"
                      type="text"
                      className="form-control"
                      placeholder={`Drop Down Item ${items?.length}`}
                      value={item.text}
                      onChange={(e) => handleValueChange(index, e.target.value)}
                      style={{
                        width: '100%',
                        paddingRight: '70px', // enough space for BOTH buttons
                      }}
                    />

                    {/* Buttons container inside input */}
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
                      {isDropdown && (
                        <button
                          className={`circle-btn ${item.correct ? 'correct' : ''}`}
                          onClick={() => toggleSelected(index)}
                          style={{
                            border: 'none',
                            background: 'transparent',
                            padding: '0',
                            cursor: 'pointer',
                          }}
                        >
                          {item.correct ? (
                            <i className="fa-solid fa-circle-check fa-lg"></i>
                          ) : (
                            <i className="fa-regular fa-circle-check fa-lg"></i>
                          )}
                        </button>
                      )}
                      {/* Remove button */}
                      <button
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
                    handleOptionDetailsSave(finalOptions);
                  }}
                >
                  Update Changes
                </button>
              </OverlayTrigger>

              <button
                className="btn btn-secondary"
                style={{ border: '1px solid gray' }}
                onClick={addItem}
              >
                <i className="fa-solid fa-plus"></i> Add item
              </button>

              <button
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
