/* eslint-disable react/prop-types */
import TimeRemaining from 'components/common/TimeRemaining';
import React, { Fragment, useState } from 'react';
import { useDispatch } from 'react-redux';
import { setScreenIdleTimeOutTriggered } from '../../store/features/adaptivity/slice';

interface ScreenIdleTimeOutDialogProps {
  remainingTime: number;
}
const ScreenIdleTimeOutDialog: React.FC<ScreenIdleTimeOutDialogProps> = ({ remainingTime }) => {
  const [isOpen, setIsOpen] = useState(true);
  const handleCloseModalClick = () => {
    setIsOpen(false);
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOut: false }));
  };
  const dispatch = useDispatch();
  const handleRestart = () => {
    setIsOpen(false);
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
              onClick={handleRestart}
              style={{ color: 'inherit', textDecoration: 'none' }}
              title="OK, Logout Lesson"
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
