import { setRestartLesson } from 'apps/delivery/store/features/adaptivity/slice';
import {
  selectEnableHistory,
  selectPreviewMode,
  selectReviewMode,
  selectShowHistory,
  setShowHistory,
} from 'apps/delivery/store/features/page/slice';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

export interface OptionsPanelProps {
  open: boolean;
}

const OptionsPanel: React.FC<OptionsPanelProps> = ({ open }) => {
  const dispatch = useDispatch();
  const enableHistory = useSelector(selectEnableHistory);
  const showHistory = useSelector(selectShowHistory);
  const isPreviewMode = useSelector(selectPreviewMode);
  const isReviewMode = useSelector(selectReviewMode);
  const handleToggleHistory = (show: boolean) => {
    dispatch(setShowHistory({ show }));
  };

  const handleRestartLesson = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  return (
    <div className="optionsPanel">
      <div className={`displayOptionsView${open ? '' : ' displayNone'}`}>
        <div className="title">Display options</div>
        <div
          className={`option navigationOption${
            enableHistory || isReviewMode ? '' : ' displayNone'
          }`}
        >
          <span className="historyText">{isPreviewMode ? 'Screen List' : 'Lesson History'}</span>
          <div className="state navigationBtn">
            <button
              className={`on btn${showHistory ? '' : ' displayNone'}`}
              aria-label="Close history panel"
              onClick={() => handleToggleHistory(false)}
            >
              <div className="left">ON</div>
            </button>
            <button
              className={`off btn${!showHistory ? '' : ' displayNone'}`}
              aria-label="Open history panel"
              onClick={() => handleToggleHistory(true)}
            >
              <div className="right">OFF</div>
            </button>
          </div>
        </div>

        {/* <div className={`option notepadOption${config.notepad?.enabled ? '' : ' displayNone'}`}>
          Notepad
          <div className="state notepadBtn">
            <button
              className={`on btn${config.notepad?.set ? '' : ' displayNone'}`}
              aria-label="Close notepad"
            >
              <div className="left">ON</div>
            </button>
            <button
              className={`off btn${!config.notepad?.set ? '' : ' displayNone'}`}
              aria-label="Open notepad"
            >
              <div className="right">OFF</div>
            </button>
          </div>
        </div> */}

        <div className="rule"></div>

        <div className="option updateDetailsOption displayNone">
          <button className="updateDetailsBtn btn" aria-label="Open update details window">
            Update Details
          </button>
        </div>
        {!isReviewMode && (
          <div className={`option restartOption${enableHistory ? '' : ' displayNone'}`}>
            <button
              className="restartBtn btn"
              aria-label="Open restart lesson window"
              onClick={handleRestartLesson}
            >
              Restart Lesson
            </button>
          </div>
        )}
        <div className="option logoutOption displayNone">
          <button className="logoutBtn btn" aria-label="Open logout window">
            Log Out
          </button>
        </div>
      </div>
    </div>
  );
};

export default OptionsPanel;
