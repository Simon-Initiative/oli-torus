/* eslint-disable react/prop-types */
import {
  selectOverviewURL,
  setScreenIdleExpirationTime,
} from 'apps/delivery/store/features/page/slice';
import { readGlobal } from 'data/persistence/extrinsic';
import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { setScreenIdleTimeOutTriggered } from '../../store/features/adaptivity/slice';

const ScreenIdleTimeOutDialog: React.FC<any> = () => {
  const [isOpen, setIsOpen] = useState(true);
  const overviewURL = useSelector(selectOverviewURL);

  const handleKeepMySessionActiveClick = async () => {
    //Now lets make a server call to continue the user session
    await readGlobal([]);
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOut: false }));
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
  };
  const dispatch = useDispatch();
  const handleSessionExpire = () => {
    dispatch(setScreenIdleExpirationTime({ screenIdleExpireTime: Date.now() }));
    setIsOpen(false);
    (window as Window).location = overviewURL;
    dispatch(setScreenIdleTimeOutTriggered({ screenIdleTimeOut: false }));
  };
  useEffect(() => {
    const timer = setTimeout(() => {
      handleSessionExpire();
    }, 60000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <>
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
          <h3>Are you still working?</h3>
        </div>

        <div className="modal-body">
          <div className="modal-body">
            <div className="type"></div>
            <div className="message">
              <p>
                Your session will timeout in <b>1 minutes</b>. You want to continue?
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

export default ScreenIdleTimeOutDialog;
