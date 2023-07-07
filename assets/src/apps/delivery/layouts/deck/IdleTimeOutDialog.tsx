/* eslint-disable react/prop-types */
import React, { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import TimeRemaining from 'components/common/TimeRemaining';
import {
  selectOverviewURL,
  setScreenIdleExpirationTime,
} from 'apps/delivery/store/features/page/slice';
import { readGlobal } from 'data/persistence/extrinsic';
import { setScreenIdleTimeOutTriggered } from '../../store/features/adaptivity/slice';

const ScreenIdleTimeOutDialog: React.FC<any> = (props) => {
  const overviewURL = useSelector(selectOverviewURL);
  const remainingTimeInMinutes = props.remainingTime;
  const handleKeepMySessionActiveClick = async () => {
    //lets make a server call to continue the user session
    await readGlobal([]);
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOutTriggered: false }));
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
  };
  const dispatch = useDispatch();
  const handleSessionExpire = () => {
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
    (window as Window).location = props.signoutUrl || overviewURL;

    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOutTriggered: false }));
  };
  useEffect(() => {
    const timer = setTimeout(() => {
      handleSessionExpire();
    }, remainingTimeInMinutes * 60 * 1000);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    // Kick off a server call so we don't have an intedeterminate state at the end of the timeout
    // where a user session might already be expired before we try to log out.
    readGlobal([]);
  }, []);

  return (
    <>
      <div className="modal-backdrop in" style={{ display: 'block', opacity: 0.5 }}></div>

      <div
        className="IdleTimeOutDialog modal in"
        data-keyboard="false"
        style={{
          display: 'block',
          top: '20%',
          left: '50%',
          width: '75%',
          height: 'max-content',
        }}
      >
        <div className="modal-header">
          <h3>Are you still working?</h3>
        </div>

        <div className="modal-body">
          <div className="modal-body">
            <div className="type"></div>
            <div className="message">
              <p>
                Your session will timeout in{' '}
                <b>
                  {<TimeRemaining remainingTimeInMinutes={remainingTimeInMinutes}></TimeRemaining>}
                </b>
                . Do you want to continue?
              </p>
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button
            className="btn btn-primary"
            name="Keep My Session Active"
            onClick={handleKeepMySessionActiveClick}
          >
            Keep My Session Active
          </button>
        </div>
      </div>
    </>
  );
};

ScreenIdleTimeOutDialog.defaultProps = {
  remainingTime: 5,
};

export default ScreenIdleTimeOutDialog;
