import React, { useCallback, useEffect, useState } from 'react';
import { Button, Modal, Spinner } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import { ScreenIcon } from '../Flowchart/screen-icons/screen-icons';
import { ScreenTypes } from '../Flowchart/screens/screen-factories';

interface Props {
  onCancel: () => void;
  onCreate: (name: string, screenType: ScreenTypes) => Promise<void>;
}

const basicPages: ScreenTypes[] = ['blank_screen']; // 'welcome_screen', 'end_screen'
const questionPages: ScreenTypes[] = [
  'multiple_choice',
  'multiline_text',
  'slider',
  'number_input',
  'text_input',
  'dropdown',
  'hub_spoke',
];

export const EXPORT_EXAMPLES_NOTE =
  'Attach/export examples will be provided to show what the screens can look like.';

export const screenTypeToTitle: Record<string, string> = {
  blank_screen: 'Instructional Screen',
  welcome_screen: 'Welcome Screen',
  multiple_choice: 'Multiple Choice',
  multiline_text: 'Multiline Text',
  slider: 'Slider',
  hub_spoke: 'Hub and Spoke',
  end_screen: 'End Screen',
  number_input: 'Number Input',
  text_input: 'Text Input',
  dropdown: 'Dropdown',
};

const NextArrow: React.FC<{ stroke?: string }> = ({ stroke = 'white' }) => (
  <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path
      d="M5 12h14M12 5l7 7-7 7"
      stroke={stroke}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const AddScreenModal: React.FC<Props> = ({ onCancel, onCreate }) => {
  const [title, setTitle] = useState('');
  const [showValidationMessage, setShowValidationMessage] = useState(false);
  const [activeScreenType, setScreenType] = useState<ScreenTypes | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  const validInput = title.length > 0 && activeScreenType !== null;
  const isOnlyScreenTypeSelected = !title?.length && activeScreenType !== null;
  const isOnlyScreenTitleSelected = title?.length && activeScreenType === null;
  const showTypeSelectedFooter = activeScreenType !== null && !showValidationMessage;
  const showFooterNote = showTypeSelectedFooter;
  const footerUsesHighlightBar = (showValidationMessage && !validInput) || showTypeSelectedFooter;

  const handleCreate = useCallback(async () => {
    if (isCreating) {
      return;
    }

    setIsCreating(true);
    try {
      await onCreate(title || 'Adaptive Screen', activeScreenType || 'blank_screen');
    } catch {
      setIsCreating(false);
    }
  }, [activeScreenType, isCreating, onCreate, title]);

  const onNext = useCallback(() => {
    if (!validInput) {
      setShowValidationMessage(true);
      return;
    }
    void handleCreate();
  }, [handleCreate, validInput]);

  const onContinue = useCallback(() => {
    void handleCreate();
  }, [handleCreate]);

  const handleCancel = useCallback(() => {
    if (!isCreating) {
      onCancel();
    }
  }, [isCreating, onCancel]);

  useEffect(() => {
    if (validInput) {
      setShowValidationMessage(false);
    }
  }, [validInput, showValidationMessage]);

  const renderActionButton = (
    label: string,
    onClick: () => void,
    className: string,
    arrowStroke: string,
  ) => (
    <Button variant="button" className={className} onClick={onClick} disabled={isCreating}>
      {isCreating && (
        <Spinner animation="border" size="sm" role="status" className="add-screen-modal-spinner" />
      )}
      {label}
      {!isCreating && <NextArrow stroke={arrowStroke} />}
    </Button>
  );

  return (
    <AdvancedAuthoringModal
      dialogClassName="modal-870 add-screen-modal"
      show={true}
      backdrop={isCreating ? 'static' : true}
      keyboard={!isCreating}
      onHide={handleCancel}
    >
      <Modal.Body>
        <input
          autoFocus
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="title-input"
          placeholder="Add screen title..."
          disabled={isCreating}
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
                  type="button"
                  className={screenType === activeScreenType ? 'screen-type active' : 'screen-type'}
                  onClick={() => setScreenType(screenType)}
                  disabled={isCreating}
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
                  type="button"
                  className={screenType === activeScreenType ? 'screen-type active' : 'screen-type'}
                  onClick={() => setScreenType(screenType)}
                  disabled={isCreating}
                >
                  <ScreenIcon screenType={screenType} fill="#f3f5f8" />
                  {screenTypeToTitle[screenType]}
                </button>
              ))}
            </div>
          </div>
        </div>
      </Modal.Body>
      <Modal.Footer className={footerUsesHighlightBar ? 'screen-not-selected' : ''}>
        {showFooterNote && (
          <span className="add-screen-modal-footer-note">
            <i className="fa fa-info-circle add-screen-modal-footer-note-icon" aria-hidden="true" />
            {EXPORT_EXAMPLES_NOTE}
          </span>
        )}
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
        {!showValidationMessage &&
          renderActionButton(
            'Next',
            onNext,
            showTypeSelectedFooter ? ' continue-button btn btn-primary' : 'btn btn-primary',
            showTypeSelectedFooter ? '#222439' : 'white',
          )}
        {showValidationMessage &&
          renderActionButton('Continue', onContinue, ' continue-button btn btn-primary', '#222439')}
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
