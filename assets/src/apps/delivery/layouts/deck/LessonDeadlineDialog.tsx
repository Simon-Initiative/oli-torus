import React, { Fragment, useCallback, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { finalizePageAttempt } from 'data/persistence/page_lifecycle';
import {
  selectIsGraded,
  selectPageSlug,
  selectPreviewMode,
  selectResourceAttemptGuid,
  selectSectionSlug,
} from '../../store/features/page/slice';

interface LessonDeadlineDialogProps {
  lateSubmit: 'allow' | 'disallow';
  onClose: () => void;
  overviewURL: string;
}

const LessonDeadlineDialog: React.FC<LessonDeadlineDialogProps> = ({
  lateSubmit,
  onClose,
  overviewURL,
}) => {
  const isPreviewMode = useSelector(selectPreviewMode);
  const graded = useSelector(selectIsGraded);
  const revisionSlug = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const resourceAttemptGuid = useSelector(selectResourceAttemptGuid);

  useEffect(() => {
    if (lateSubmit === 'disallow' && !isPreviewMode && graded) {
      /*
        We'll attempt to finalize the page, but the return value is not important since it'll get done server-side a minute later anyway.
      */
      finalizePageAttempt(sectionSlug, revisionSlug, resourceAttemptGuid);
    }
  }, []);

  const handleCloseModalClick = useCallback(() => {
    onClose && onClose();
    if (lateSubmit === 'disallow') {
      if (!graded || isPreviewMode) {
        window.location.reload();
      } else {
        window.location.href = overviewURL;
      }
    }
  }, [isPreviewMode]);

  return (
    <Fragment>
      <div className="modal-backdrop in" style={{ display: 'block', opacity: '0.5' }}></div>
      <div
        className="finishedDialog modal in"
        tabIndex={-1}
        role="dialog"
        aria-labelledby="modalDialogContent"
        style={{
          display: 'block',
          minHeight: '250px',
          height: 'unset',
          width: '500px',
          top: '20%',
          left: '50%',
        }}
      >
        <div className="modal-header" style={{ border: 'none', marginBottom: '50px' }}>
          <button
            onClick={handleCloseModalClick}
            type="button"
            className="close icon-clear"
            title="Close feedback window"
            aria-label="Close feedback window"
            data-dismiss="modal"
          />
        </div>
        <div className="modal-body" style={{ textAlign: 'center' }}>
          {lateSubmit === 'allow' ? <LateSubmitAllowedMessage /> : <LateSubmitDisallowedMessage />}
        </div>
      </div>
    </Fragment>
  );
};

const LateSubmitAllowedMessage: React.FC = () => {
  return (
    <div>
      {' '}
      <h1 className="text-2xl">Submission Deadline Passed</h1>
      <p className="text-base">
        The deadline for this activity has passed. You can still submit your work for grading, but
        it will be marked as late.
      </p>
    </div>
  );
};

const LateSubmitDisallowedMessage: React.FC = () => {
  return (
    <div>
      <h1 className="text-2xl">Submission Deadline Passed</h1>
      <p className="text-base">
        The deadline for this activity has passed. Your work so far has been submitted. You can no
        longer submit additional work for grading.
      </p>
    </div>
  );
};

export default LessonDeadlineDialog;
