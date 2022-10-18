import React, { Fragment, useState } from 'react';
import { useSelector } from 'react-redux';
import {
  selectPreviewMode,
  selectOverviewURL,
  selectFinalizeGradedURL,
} from '../../store/features/page/slice';
import { selectIsGraded } from 'apps/authoring/store/page/slice';

interface LessonFinishedDialogProps {
  imageUrl?: string;
  message: string;
}

const LessonFinishedDialog: React.FC<LessonFinishedDialogProps> = ({
  imageUrl,
  message,
}: {
  imageUrl: string;
  message: string;
}) => {
  const [isOpen, setIsOpen] = useState(true);
  const isPreviewMode = useSelector(selectPreviewMode);
  const graded = useSelector(selectIsGraded);
  const overviewURL = useSelector(selectOverviewURL);
  const finalizeGradedURL = useSelector(selectFinalizeGradedURL);

  const handleCloseModalClick = () => {
    setIsOpen(false);
    if (isPreviewMode) {
      window.location.reload();
    }
  };

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
          <a
            onClick={handleCloseModalClick}
            href={isPreviewMode ? '#' : graded ? finalizeGradedURL : overviewURL}
            className="close icon-clear"
            title="Close feedback window"
            aria-label="Close feedback window"
            data-dismiss="modal"
          />
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
