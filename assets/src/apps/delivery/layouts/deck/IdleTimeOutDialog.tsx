/* eslint-disable react/prop-types */
import {
  selectIsInstructor,
  selectPageSlug,
  selectPreviewMode,
  selectSectionSlug,
} from 'apps/delivery/store/features/page/slice';
import TimeRemaining from 'components/common/TimeRemaining';
import React, { Fragment, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { setScreenIdleTimeOutTriggered } from '../../store/features/adaptivity/slice';

interface ScreenIdleTimeOutDialogProps {
  remainingTime: number;
}
const ScreenIdleTimeOutDialog: React.FC<ScreenIdleTimeOutDialogProps> = ({ remainingTime }) => {
  const [isOpen, setIsOpen] = useState(true);
  const projectSlug = useSelector(selectSectionSlug);
  const resourceSlug = useSelector(selectPageSlug);
  const [logOutButtonUrl, setLogOutButtonUrl] = useState('');
  const [logOutButtonText, setLogOutButtonText] = useState('Back to Overview');
  const isPreviewMode = useSelector(selectPreviewMode);
  const isInstructor = useSelector(selectIsInstructor);

  useEffect(() => {
    if (isPreviewMode && !isInstructor) {
      // return to authoring
      setLogOutButtonUrl(`/authoring/project/${projectSlug}/resource/${resourceSlug}`);
      setLogOutButtonText('Back to Authoring');
    } else {
      // return to Overview
      setLogOutButtonUrl(window.location.href.split('/page')[0] + '/overview');
      setLogOutButtonText('Back to Overview');
    }
  }, [isPreviewMode]);
  const handleCloseModalClick = () => {
    setIsOpen(false);
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOut: false }));
  };
  const dispatch = useDispatch();
  const handleSessionExpire = () => {
    setIsOpen(false);
    (window as Window).location = `/authoring/project/${projectSlug}/resource/${resourceSlug}`;
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOut: false }));
  };

  return (
    <Fragment>
      <div
        className="modal-backdrop in"
        style={{ display: isOpen ? 'block' : 'none', opacity: 0.5 }}
      ></div>

      <div
        className="IdleTimeOutDialog modal in"
        data-keyboard="false"
        aria-hidden={!isOpen}
        style={{ display: isOpen ? 'block' : 'none', top: '20%', left: '50%' }}
      >
        <div className="modal-header">
          <button
            type="button"
            className="close"
            title="Close IdleTimeOutDialog Lesson window"
            aria-label="Close IdleTimeOutDialog Lesson window"
            data-dismiss="modal"
            onClick={handleCloseModalClick}
          >
            ×
          </button>
          <h3>You Have Been Idle!</h3>
        </div>

        <div className="modal-body">
          <div className="modal-body">
            <div className="type"></div>
            <div className="message">
              <p>
                Your session will timeout in{' '}
                <b>
                  {
                    <TimeRemaining
                      onTimerEnd={handleSessionExpire}
                      liveUpdate={true}
                      remainingTimeInMinutes={remainingTime}
                    ></TimeRemaining>
                  }
                </b>
                . You want to continue?
              </p>
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn">
            <a
              href={logOutButtonUrl}
              style={{ color: 'inherit', cursor: 'pointer', textDecoration: 'none' }}
              title={logOutButtonText}
              aria-label="OK, Logout Lesson"
              data-dismiss="modal"
            >
              Logout
            </a>
          </button>
          <button
            className="btn btn-primary"
            name="Keep My Session Active"
            onClick={handleCloseModalClick}
          >
            Keep My Session Active
          </button>
        </div>
      </div>
    </Fragment>
  );
};

export default ScreenIdleTimeOutDialog;
