import React, { Fragment, useCallback, useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { ActionResult, finalizePageAttempt } from 'data/persistence/page_lifecycle';
import {
  selectIsGraded,
  selectPageSlug,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectSectionSlug,
} from '../../store/features/page/slice';

interface LessonFinishedDialogProps {
  imageUrl?: string;
  message: string;
  hideCloseButton?: boolean;
}

const LessonFinishedDialog: React.FC<LessonFinishedDialogProps> = ({
  imageUrl,
  message,
  hideCloseButton,
}) => {
  const [isOpen, setIsOpen] = useState(true);
  const [redirectURL, setRedirectURL] = useState('');
  const isPreviewMode = useSelector(selectPreviewMode);
  const graded = useSelector(selectIsGraded);
  const revisionSlug = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const resourceAttemptGuid = useSelector(selectResourceAttemptGuid);

  const [finalizationCalled, setFinalizationCalled] = useState(false);
  const [isFinalized, setIsFinalized] = useState(false);

  const handleCloseModalClick = useCallback(() => {
    if (!isFinalized) {
      // try again in a sec
      setTimeout(handleCloseModalClick, 1000);
      return;
    }
    setIsOpen(false);
    if (!graded || isPreviewMode) {
      window.location.reload();
    } else {
      window.location.href = redirectURL;
    }
  }, [isFinalized, isPreviewMode, redirectURL]);

  const handleFinalization = useCallback(async () => {
    setFinalizationCalled(true);
    if (!isPreviewMode && graded) {
      // only graded pages are finalized
      try {
        const finalizeResult = await finalizePageAttempt(
          sectionSlug,
          revisionSlug,
          resourceAttemptGuid,
        );
        console.log('finalize attempt result: ', finalizeResult);
        if (finalizeResult.result === 'success') {
          if ((finalizeResult as ActionResult).commandResult === 'failure') {
            console.error('failed to finalize attempt', finalizeResult);
            return;
          }
          setRedirectURL(finalizeResult.redirectTo);
        } else {
          console.error('failed to finalize attempt (SERVER ERROR)', finalizeResult);
          return;
        }
      } catch (e) {
        console.error('finalization error: ', e);
        /* setFinalizationCalled(false); // so can try again */
        return;
      }
    }
    setIsFinalized(true);
  }, [sectionSlug, revisionSlug, resourceAttemptGuid, graded, isPreviewMode]);

  useEffect(() => {
    // TODO: maybe we should call finalization elsewhere than in this modal
    if (isOpen && !finalizationCalled) {
      handleFinalization();
    }
  }, [isOpen, finalizationCalled, handleFinalization]);

  function HTMLMessage() {
    return { __html: message };
  }

  return (
    <Fragment>
      <div
        className="modal-backdrop in"
        style={{ display: isOpen ? 'block' : 'none', opacity: '0.5' }}
      ></div>
      <div
        className="finishedDialog modal in"
        tabIndex={-1}
        role="dialog"
        aria-labelledby="modalDialogContent"
        aria-hidden={!isOpen}
        style={{
          display: isOpen ? 'block' : 'none',
          height: '350px',
          width: '500px',
          top: '20%',
          backgroundImage: imageUrl ? `url('${imageUrl}')` : '',
          left: '50%',
        }}
      >
        <div className="modal-header" style={{ border: 'none', marginBottom: '50px' }}>
          {hideCloseButton || (
            <button
              onClick={handleCloseModalClick}
              type="button"
              className="close icon-clear"
              title="Close feedback window"
              aria-label="Close feedback window"
              data-dismiss="modal"
            />
          )}
        </div>
        <div
          id="lessonFinishedDialogContent"
          className="modal-body"
          style={{ textAlign: 'center', marginTop: '110px', height: '190px' }}
          dangerouslySetInnerHTML={HTMLMessage()}
        ></div>
      </div>
    </Fragment>
  );
};

export default LessonFinishedDialog;
