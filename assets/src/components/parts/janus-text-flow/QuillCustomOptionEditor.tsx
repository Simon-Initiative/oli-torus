import React, { useState } from 'react';
import { Modal } from 'react-bootstrap';

export interface QuillCustomOptionProps {
  text: string;
  correct: boolean;
}
interface QuillCustomOptionEditorProps {
  optionType: 'Drop Down' | 'Input';
  handleImageDetailsSave: (options: Array<QuillCustomOptionProps>) => void;
  handleImageDailogClose: () => void;
  showImageSelectorDailog?: boolean;
}
export const QuillCustomOptionEditor: React.FC<QuillCustomOptionEditorProps> = ({
  handleImageDetailsSave,
  showImageSelectorDailog,
  handleImageDailogClose,
  optionType,
}) => {
  const [items, setItems] = useState([
    { text: `${optionType == 'Drop Down' ? 'Drop Down Item' : 'Correct Answer'} 1`, correct: true },
    {
      text: `${optionType == 'Drop Down' ? 'Drop Down Item' : 'Correct Answer'} 2`,
      correct: optionType != 'Drop Down',
    },
  ]);
  const handleValueChange = (index: number, text: string) => {
    const updated = [...items];
    updated[index].text = text;
    setItems(updated);
  };

  const toggleSelected = (index: number) => {
    const updated = items.map((item, i) => ({
      ...item,
      correct: i === index,
    }));
    setItems(updated);
  };

  const removeItem = (index: number) => {
    const updated = items.filter((_, i) => i !== index);
    setItems(updated);
  };

  const addItem = () => {
    setItems([
      ...items,
      {
        text: `${optionType == 'Drop Down' ? 'Drop Down Item' : 'Correct Answer'} ${
          items?.length + 1
        }`,
        correct: optionType != 'Drop Down',
      },
    ]);
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
                {optionType == 'Drop Down' ? 'Drop Down Items' : 'Correct Answer(s)'}
              </h3>
            </Modal.Header>
            <Modal.Body className="px-8" style={{ backgroundColor: 'lightgray' }}>
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
                      {optionType == 'Drop Down' && (
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
              <button
                id="btnDelete"
                className="btn btn-primary flex-grow basis-1"
                onClick={() => {
                  handleImageDetailsSave([{ correct: false, text: '' }]);
                }}
              >
                {optionType == 'Drop Down' ? `Update Drop down` : 'Update input'}
              </button>
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
