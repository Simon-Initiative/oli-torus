import React, { useCallback, useEffect } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
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
  const dispatch = useDispatch();
  const [title, setTitle] = React.useState('');
  const [showValidationMessage, setShowValidationMessage] = React.useState(false);
  const [activeScreenType, setScreenType] = React.useState<ScreenTypes | null>(null);
  const onNext = useCallback(() => {
    if (!validInput) {
      setShowValidationMessage(true);
    } else {
      onCreate(title || 'Adaptive Screen', activeScreenType || 'blank_screen');
      dispatch(setCurrentPartPropertyFocus({ focus: false }));
    }
  }, [activeScreenType, onCreate, title]);
  const onContinue = useCallback(() => {
    onCreate(title || 'Adaptive Screen', activeScreenType || 'blank_screen');
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
  }, [activeScreenType, onCreate, title]);

  const validInput = title.length > 0 && activeScreenType !== null;
  const isOnlyScreenTypeSelected = !title?.length && activeScreenType !== null;
  const isOnlyScreenTitleSelected = title?.length && activeScreenType === null;
  useEffect(() => {
    if (validInput) {
      setShowValidationMessage(false);
    }
  }, [validInput, showValidationMessage]);
  return (
    <AdvancedAuthoringModal
      dialogClassName="modal-870 add-screen-modal"
      show={true}
      onHide={onCancel}
    >
      <Modal.Body>
        <input
          autoFocus
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="title-input"
          placeholder="Add screen title..."
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

          <div className="column screen-with-component">
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
      <Modal.Footer
        className={
          showValidationMessage &&
          (isOnlyScreenTitleSelected || !validInput || isOnlyScreenTypeSelected)
            ? 'screen-not-selected'
            : ''
        }
      >
        {showValidationMessage && !validInput && (
          <span style={{ alignSelf: 'flex-start' }}>
            <b>Are you sure?</b> <span style={{ fontSize: 'x-large' }}>| </span>A{' '}
            {isOnlyScreenTypeSelected
              ? 'screen title '
              : isOnlyScreenTitleSelected
              ? 'screen type'
              : ' screen title and screen type'}{' '}
            may be helpful while creating a lesson.
          </span>
        )}
        {!showValidationMessage && (
          <Button variant="button" className="btn btn-primary" onClick={onNext}>
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
                stroke="white"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </Button>
        )}
        {showValidationMessage && (
          <Button
            variant="button"
            className=" continue-button btn btn-primary"
            onClick={onContinue}
          >
            Continue
            <svg
              width={24}
              height={24}
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M5 12h14M12 5l7 7-7 7"
                stroke="#2c6abf"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </Button>
        )}
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
