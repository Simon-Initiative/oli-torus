/* eslint-disable react/prop-types */
import React, { Fragment, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { setRestartLesson } from '../../store/features/adaptivity/slice';
import { selectPreviewMode } from '../../store/features/page/slice';

interface RestartLessonDialogProps {
  onRestart: () => void;
}
const RestartLessonDialog: React.FC<RestartLessonDialogProps> = ({ onRestart }) => {
  const [isOpen, setIsOpen] = useState(true);

  const handleCloseModalClick = () => {
    setIsOpen(false);
    dispatch(setRestartLesson({ restartLesson: false }));
  };
  const dispatch = useDispatch();
  const isPreviewMode = useSelector(selectPreviewMode);

  const handleRestart = () => {
    if (isPreviewMode) {
      window.location.reload();
    } else {
      const currentUrl = window.location.href;
      if (currentUrl.indexOf('/attempt') > 0) {
        window.location.reload();
      }
      window.location.href = `${currentUrl}/attempt`;
    }
  };

  return (
    <Fragment>
      <div
        className="modal-backdrop in"
        style={{ display: isOpen ? 'block' : 'none', opacity: 0.5 }}
      ></div>

      <div
        className="RestartLessonDialog modal in"
        data-keyboard="false"
        aria-hidden={!isOpen}
        style={{ display: isOpen ? 'block' : 'none', top: '20%', left: '50%' }}
      >
        <div className="modal-header">
          <button
            type="button"
            className="close"
            title="Close Restart Lesson window"
            aria-label="Close Restart Lesson window"
            data-dismiss="modal"
            onClick={handleCloseModalClick}
          >
            ×
          </button>
          <h3>Restart Lesson</h3>
        </div>

        <div className="modal-body">
          <div className="type"></div>
          <div className="message">
            <p>Are you sure you want to restart and begin from the first screen?</p>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn " name="OK" onClick={handleRestart}>
            OK
          </button>
          <button className="btn " name="CANCEL" onClick={handleCloseModalClick}>
            Cancel
          </button>
        </div>
      </div>
    </Fragment>
  );
};

export default RestartLessonDialog;
