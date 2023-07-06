import React, { useCallback } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import { ScreenIcon } from '../Flowchart/screen-icons/screen-icons';
import { ScreenTypes } from '../Flowchart/screens/screen-factories';

interface Props {
  onCancel: () => void;
  onCreate: (name: string, screenType: ScreenTypes) => void;
}

const basicPages: ScreenTypes[] = ['blank_screen']; // 'welcome_screen', 'end_screen'
const questionPages: ScreenTypes[] = [
  'multiple_choice',
  'multiline_text',
  'slider',
  'number_input',
  'text_input',
  'dropdown',
]; //'hub_and',

export const screenTypeToTitle: Record<string, string> = {
  blank_screen: 'Instructional Screen',
  welcome_screen: 'Welcome Screen',
  multiple_choice: 'Multiple Choice',
  multiline_text: 'Multiline Text',
  slider: 'Slider',
  hub_and: 'Hub and Spoke',
  end_screen: 'End Screen',
  number_input: 'Number Input',
  text_input: 'Text Input',
  dropdown: 'Dropdown',
};

export const AddScreenModal: React.FC<Props> = ({ onCancel, onCreate }) => {
  const [title, setTitle] = React.useState('');
  const [activeScreenType, setScreenType] = React.useState<ScreenTypes | null>(null);

  const onNext = useCallback(() => {
    onCreate(title, activeScreenType || 'blank_screen');
  }, [activeScreenType, onCreate, title]);

  const validInput = title.length > 0 && activeScreenType !== null;

  return (
    <AdvancedAuthoringModal
      dialogClassName="modal-800 add-screen-modal"
      show={true}
      onHide={onCancel}
    >
      <Modal.Body>
        <input
          autoFocus
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="title-input"
          placeholder="Name your screen here"
        />
        <hr />
        <h2>Select the screen type</h2>
        <div className="columns">
          <div className="column">
            <label>Basic</label>
            <div>
              {basicPages.map((screenType) => (
                <button
                  key={screenType}
                  className={screenType === activeScreenType ? 'screen-type active' : 'screen-type'}
                  onClick={() => setScreenType(screenType)}
                >
                  <div className="screen-box" />
                  <ScreenIcon screenType={screenType} fill="#f3f5f8" />
                  {screenTypeToTitle[screenType]}
                </button>
              ))}
            </div>
          </div>

          <div className="column">
            <label>Screen with choices component</label>
            <div className="grid">
              {questionPages.map((screenType) => (
                <button
                  key={screenType}
                  className={screenType === activeScreenType ? 'screen-type active' : 'screen-type'}
                  onClick={() => setScreenType(screenType)}
                >
                  <ScreenIcon screenType={screenType} fill="#f3f5f8" />
                  {screenTypeToTitle[screenType]}
                </button>
              ))}
            </div>
          </div>
        </div>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="link" onClick={onNext} disabled={!validInput}>
          Next
          <svg
            width={24}
            height={24}
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M5 12h14M12 5l7 7-7 7"
              stroke={validInput ? '#2C6ABF' : '#b1b1b1'}
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </Button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
