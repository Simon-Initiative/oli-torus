/* eslint-disable react/prop-types */
import { finalizePageAttempt } from 'data/persistence/page_lifecycle';
import React, { Fragment, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { setRestartLesson } from '../../store/features/adaptivity/slice';
import {
  selectFinalizeGradedURL,
  selectIsGraded,
  selectOverviewURL,
  selectPageSlug,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectSectionSlug,
} from '../../store/features/page/slice';

interface RestartLessonDialogProps {
  onRestart: () => void;
}
const RestartLessonDialog: React.FC<RestartLessonDialogProps> = ({ onRestart }) => {
  const [isOpen, setIsOpen] = useState(true);

  const revisionSlug = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const resourceAttemptGuid = useSelector(selectResourceAttemptGuid);

  const graded = useSelector(selectIsGraded);
  const overviewURL = useSelector(selectOverviewURL);
  const finalizeGradedURL = useSelector(selectFinalizeGradedURL);
  const handleCloseModalClick = () => {
    setIsOpen(false);
    dispatch(setRestartLesson({ restartLesson: false }));
  };
  const dispatch = useDispatch();
  const isPreviewMode = useSelector(selectPreviewMode);

  const handleRestart = async () => {
    if (onRestart) {
      onRestart();
    }
    if (!isPreviewMode && graded) {
      const finalizeResult = await finalizePageAttempt(
        sectionSlug,
        revisionSlug,
        resourceAttemptGuid,
      );
      /* console.log('finalizeResult', finalizeResult); */
    }
    if (graded || isPreviewMode) {
      window.location.reload();
    } else {
      // FIXME: for hotfix purposes, just reverting the code
      // going fwd however it should use a parameter sent from the backend instead
      const newAttemptUrl = `/sections/${sectionSlug}/page/${revisionSlug}/attempt`;
      window.location.href = newAttemptUrl;
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
            <p>
              {graded
                ? 'Are you sure you want to restart? This will end your current attempt and allow you to begin the lesson from the first screen.'
                : 'Are you sure you want to restart and begin from the first screen?'}
            </p>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn">
            <a
              onClick={handleRestart}
              href={isPreviewMode ? '#' : graded ? finalizeGradedURL : overviewURL}
              style={{ color: 'inherit', textDecoration: 'none' }}
              title="OK, Restart Lesson"
              aria-label="OK, Restart Lesson"
              data-dismiss="modal"
            >
              OK
            </a>
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
