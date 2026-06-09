import React, { Fragment, useCallback, useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { ActionFailure, ActionResult, finalizePageAttempt } from 'data/persistence/page_lifecycle';
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
  const [finalizeError, setFinalizeError] = useState<string | null>(null);
  const isPreviewMode = useSelector(selectPreviewMode);
  const graded = useSelector(selectIsGraded);
  const revisionSlug = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const resourceAttemptGuid = useSelector(selectResourceAttemptGuid);

  const [finalizationCalled, setFinalizationCalled] = useState(false);
  const [isFinalized, setIsFinalized] = useState(false);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const modalRef = useRef<HTMLDivElement>(null);

  const handleCloseModalClick = useCallback(() => {
    if (!isFinalized) {
      setTimeout(handleCloseModalClick, 1000);
      return;
    }
    setIsOpen(false);
    if (isPreviewMode) {
      window.location.reload();
    } else if (redirectURL) {
      window.location.href = redirectURL;
    } else {
      window.location.reload();
    }
  }, [isFinalized, isPreviewMode, redirectURL]);

  const handleFinalization = useCallback(async () => {
    setFinalizationCalled(true);
    if (!isPreviewMode) {
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
            switch ((finalizeResult as ActionFailure).reason) {
              case 'already_submitted':
                setFinalizeError(
                  'This assignment was already submitted. This may be due to it being autosubmitted for a deadline.',
                );
                setIsFinalized(true);
                break;
              default:
                setFinalizeError('Could not submit assignment: Unknown Reason.');
                break;
            }
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
    if (!isPreviewMode && redirectURL && redirectURL.includes('/review')) {
      try {
        const url = new URL(redirectURL, window.location.href);

        if (url.origin === window.location.origin) {
          window.history.replaceState({}, '', url.toString());
        }
      } catch (error) {
        console.warn('failed to update history for review redirect', error);
      }
    }
  }, [redirectURL, isPreviewMode]);

  useEffect(() => {
    // TODO:  maybe we should call finalization elsewhere than in this modal
    if (isOpen && !finalizationCalled) {
      handleFinalization();
    }
  }, [isOpen, finalizationCalled, handleFinalization]);

  useEffect(() => {
    if (!isOpen) return;

    const focusModalControl = () => {
      if (hideCloseButton) {
        modalRef.current?.focus();
      } else {
        closeButtonRef.current?.focus();
      }
    };

    let timeoutId: ReturnType<typeof setTimeout>;
    const frameId = requestAnimationFrame(() => {
      timeoutId = setTimeout(focusModalControl, 100);
    });

    return () => {
      cancelAnimationFrame(frameId);
      clearTimeout(timeoutId);
    };
  }, [isOpen, hideCloseButton]);

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
        ref={modalRef}
        className="finishedDialog modal in"
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="lessonFinishedDialogContent"
        aria-hidden={!isOpen}
        style={{
          display: isOpen ? 'block' : 'none',
          minHeight: '250px',
          height: 'unset',
          width: '500px',
          top: '25%',
          backgroundImage: imageUrl ? `url('${imageUrl}')` : '',
          left: '50%',
        }}
      >
        <div className="modal-header" style={{ border: 'none', marginBottom: '50px' }}>
          {hideCloseButton || (
            <button
              ref={closeButtonRef}
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
        {finalizeError && <div className="mx-2 alert alert-danger">{finalizeError}</div>}
      </div>
    </Fragment>
  );
};

export default LessonFinishedDialog;
