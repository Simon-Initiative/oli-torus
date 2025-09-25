/* eslint-disable react/prop-types */
import React, { Fragment, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ActionResult, finalizePageAttempt } from 'data/persistence/page_lifecycle';
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

const sendUserTo = (url: string) => {
  // If we want to send the user to the current URL, just reload, otherwise set the
  // topmost url we can to the target (to avoid our "Display Torus Navigation" iframe inside itself)

  if (window.location.pathname === url || window.location.href === url) {
    window.location.reload();
    return;
  }
  if (window.top) {
    try {
      window.top.location = url;
    } catch (e) {
      window.location.href = url;
    }
  } else {
    window.location.href = url;
  }
};

const RestartLessonDialog: React.FC<RestartLessonDialogProps> = ({ onRestart }) => {
  const [isOpen, setIsOpen] = useState(true);
  const [isLoading, setIsLoading] = useState(false);

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
    console.info('Restarting lesson...', onRestart);
    setIsLoading(true);

    // We only want to restart if we are in preview mode or the page is not graded
    if ((isPreviewMode || !graded) && onRestart) {
      onRestart();
    }

    let redirectTo = overviewURL;
    if (!isPreviewMode && graded) {
      const finalizeResult = await finalizePageAttempt(
        sectionSlug,
        revisionSlug,
        resourceAttemptGuid,
      );

      console.log('finalize attempt result: ', finalizeResult);
      if (finalizeResult.result === 'success') {
        if ((finalizeResult as ActionResult).commandResult === 'failure') {
          console.error('failed to finalize attempt', finalizeResult);
          // try again the other way
          redirectTo = finalizeGradedURL;
        } else {
          redirectTo = finalizeResult.restartUrl || finalizeResult.redirectTo;
        }
      } else {
        console.error('failed to finalize attempt (SERVER ERROR)', finalizeResult);
        // try again the other way
        redirectTo = finalizeGradedURL;
      }
    } else if (!isPreviewMode && !graded) {
      const newAttemptUrl = `/sections/${sectionSlug}/page/${revisionSlug}/attempt`;
      redirectTo = newAttemptUrl;
    }
    if (isPreviewMode) {
      window.location.reload();
    } else {
      sendUserTo(redirectTo);
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
        style={{
          maxWidth: '600px',
          display: isOpen ? 'block' : 'none',
          top: '20%',
          left: '50%',
          height: 'max-content',
        }}
      >
        <div className="modal-header">
          <h3>{graded ? 'Submit Attempt' : 'Restart Lesson'}</h3>
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
          <button className="btn" onClick={handleRestart}>
            <a
              style={{ color: 'inherit', textDecoration: 'none' }}
              title="OK, Restart Lesson"
              aria-label="OK, Restart Lesson"
              data-dismiss="modal"
            >
              {isLoading ? 'Restarting...' : 'OK'}
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
