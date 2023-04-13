import React, { useCallback } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import { ScreenTypes } from '../Flowchart/screens/screen-factories';

interface Props {
  onCancel: () => void;
  onCreate: (name: string, screenType: ScreenTypes) => void;
}

const basicPages: ScreenTypes[] = ['blank_screen', 'welcome_screen', 'end_screen'];
const questionPages: ScreenTypes[] = [
  'multiple_choice',
  'multiline_text',
  'slider',
  'hub_and',
  'number_input',
  'text_input',
  'dropdown',
];

export const screenTypeToTitle: Record<string, string> = {
  blank_screen: 'Blank Screen',
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

  return (
    <AdvancedAuthoringModal
      dialogClassName="modal-90w add-screen-modal"
      show={true}
      onHide={onCancel}
    >
      <Modal.Body>
        <input
          autoFocus
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="form-control"
          placeholder="Name your screen here"
        />
        <hr />
        <h2>Select the screen type</h2>
        <div className="columns">
          <div className="column">
            <label>Basic</label>
            <div className="grid">
              {basicPages.map((screenType) => (
                <button
                  key={screenType}
                  className={screenType === activeScreenType ? 'screen-type active' : 'screen-type'}
                  onClick={() => setScreenType(screenType)}
                >
                  <div className="screen-box" />
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
                  <div className="screen-box" />
                  {screenTypeToTitle[screenType]}
                </button>
              ))}
            </div>
          </div>
        </div>
      </Modal.Body>
      <Modal.Footer>
        <Button onClick={onNext} disabled={title.length === 0}>
          Next
        </Button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
