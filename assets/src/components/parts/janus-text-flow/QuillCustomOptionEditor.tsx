import React, { useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';

export interface QuillCustomOptionProps {
  text: string;
  correct: boolean;
}

export interface OptionItem {
  key: string;
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
}

interface QuillCustomOptionEditorProps {
  handleImageDetailsSave: (options: Array<OptionItem>) => void;
  handleImageDailogClose: () => void;
  showImageSelectorDailog?: boolean;
  Options: OptionItem[];
}

export const QuillCustomOptionEditor: React.FC<QuillCustomOptionEditorProps> = ({
  handleImageDetailsSave,
  showImageSelectorDailog,
  handleImageDailogClose,
  Options,
}) => {
  const [selectedKey, setSelectedKey] = useState<string>(Options[0]?.key || '');
  const [items, setItems] = useState<QuillCustomOptionProps[]>([]);
  const [finalOptions, setFinalOptions] = useState<OptionItem[]>([]);

  const selectedOption = finalOptions.find((opt) => opt.key === selectedKey);
  const isDropdown = selectedOption?.type === 'dropdown';
  const isValidItem = selectedOption?.options?.length && selectedOption?.correct?.length;
  useEffect(() => {
    setFinalOptions(Options);
  }, [Options]);

  useEffect(() => {
    let current = finalOptions.find((opt) => opt.key === selectedKey);
    if (finalOptions?.length && !current) {
      setSelectedKey(finalOptions[0]?.key);
      current = finalOptions[0];
    }
    if (current) {
      setItems(
        current.options.map((opt) => ({
          text: opt,
          correct: current.type === 'dropdown' ? current.correct === opt : true,
        })),
      );
    }
  }, [selectedKey, finalOptions]);

  const updateOptionItems = (updatedItems: QuillCustomOptionProps[]) => {
    const updatedOptions = updatedItems.map((item) => item.text);
    const correctItem = updatedItems.find((item) => item.correct)?.text || '';

    setFinalOptions((prev) =>
      prev.map((opt) =>
        opt.key === selectedKey
          ? {
              ...opt,
              options: updatedOptions,
              correct: opt.type === 'dropdown' ? correctItem : 'true',
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
    const updated = items.map((item, i) => ({ ...item, correct: i === index }));
    setItems(updated);
    updateOptionItems(updated);
  };

  const removeItem = (index: number) => {
    const isCorrectRemoved = items[index].correct;
    const updated = items.filter((_, i) => i !== index);
    const adjusted = updated.map((item) => ({
      ...item,
      correct: isCorrectRemoved ? false : item.correct,
    }));
    setItems(adjusted);
    updateOptionItems(adjusted);
  };

  const addItem = () => {
    const newItem = {
      text: `${isDropdown ? 'Drop Down Item' : 'Correct Answer'} ${items.length + 1}`,
      correct: !isDropdown,
    };
    const updated = [...items, newItem];
    setItems(updated);
    updateOptionItems(updated);
  };

  return (
    <React.Fragment>
      {
        <>
          <Modal
            show={showImageSelectorDailog}
            onHide={handleImageDailogClose}
            style={{ top: '225px' }}
          >
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
                  onChange={(e) => setSelectedKey(e.target.value)}
                >
                  {Options.map((option) => (
                    <option key={option.key} value={option.key}>
                      {option.key}
                    </option>
                  ))}
                </select>
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
                        <div>A correct answer is required.</div>
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
                    handleImageDetailsSave(finalOptions);
                  }}
                >
                  Update Changes
                </button>
              </OverlayTrigger>
              {isDropdown ||
                (!selectedOption?.options?.length && (
                  <button
                    className="btn btn-secondary"
                    style={{ border: '1px solid gray' }}
                    onClick={addItem}
                  >
                    <i className="fa-solid fa-plus"></i> Add item
                  </button>
                ))}
              <button
                className="btn btn-default"
                style={{ border: '1px solid gray' }}
                onClick={handleImageDailogClose}
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
