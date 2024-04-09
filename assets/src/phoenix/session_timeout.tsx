import React, { ReactElement, useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';
import ReactDOM from 'react-dom';

// Constant value used to configure the time before the warning message is displayed
// ms * sec * min example: 1000 * 60 * 5 = 5 minutes
const timeBeforeWarningMs = 1000 * 60 * 5;

// This is the entry point for the session timeout feature.
export function sessionTimeout() {
  setTimeout(triggerTimers, 1000);
}

const unmountReactSessionExpContainer = () => {
  ReactDOM.unmountComponentAtNode(document.getElementById('sessionExpirationContainerId')!);
};

const SessionExpirationWarningComponent = (props: any) => {
  const [isEntering, setIsEntering] = React.useState<boolean>(false);

  setTimeout(() => {
    setIsEntering(true);
  });
  return (
    <div id="sessionExpirationId" className="fixed right-0" style={{ zIndex: 99 }}>
      <div
        className={`${isEntering ? 'opacity-100' : 'opacity-0'} ${isEntering ? 'translate-y-[0px]' : 'translate-y-[-25px]'
          } transform transition duration-700 ease-in flex gap-2 items-center p-4 mb-4 text-sm text-yellow-800 rounded-lg bg-yellow-50 dark:bg-gray-800 dark:text-yellow-300 border-2 border-solid border-yellow-300`}
        role="alert"
      >
        <svg
          className="flex-shrink-0 inline w-4 h-4 me-3"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z" />
        </svg>
        <span className="sr-only">Info</span>
        <div>
          <span>{props.message}</span>
          <span className="font-medium">Warning!</span> Your session will expire in{' '}
          <Timer initialMinute={props.minutes} initialSeconds={props.seconds} /> due to inactivity.
        </div>
        <button
          type="button"
          onClick={unmountReactSessionExpContainer}
          className="text-yellow-800 bg-transparent border border-yellow-800 hover:bg-yellow-900 hover:text-white focus:ring-4 focus:outline-none focus:ring-yellow-300 font-medium rounded-lg text-xs px-3 py-1.5 text-center dark:hover:bg-yellow-300 dark:border-yellow-300 dark:text-yellow-300 dark:hover:text-gray-800 dark:focus:ring-yellow-800"
          data-dismiss-target="#alert-additional-content-4"
          aria-label="Close"
        >
          Close
        </button>
      </div>
    </div>
  );
};

const SessionTimeoutComponent = () => {
  const reloadPage = () => {
    unmountReactSessionExpContainer();
    window.location.reload();
  };
  return (
    <Modal
      dialogClassName={`session-modal`}
      show={true}
      enforceFocus={true}
      style={{ overflow: 'auto' }}
    >
      <Modal.Header>
        <span className="title">Your session has expired</span>
      </Modal.Header>
      <Modal.Body>Please log in again.</Modal.Body>
      <Modal.Footer>
        <button
          type="button"
          onClick={reloadPage}
          className="btn btn-secondary"
          data-dismiss="modal"
        >
          Close
        </button>
      </Modal.Footer>
    </Modal>
  );
};

// https://stackoverflow.com/questions/40885923/countdown-timer-in-react
const Timer = (props: any) => {
  const { initialMinute = 0, initialSeconds = 0 } = props;
  const [minutes, setMinutes] = useState(initialMinute);
  const [seconds, setSeconds] = useState(initialSeconds);
  useEffect(() => {
    const myInterval = setInterval(() => {
      if (seconds > 0) {
        setSeconds(seconds - 1);
      }
      if (seconds === 0) {
        if (minutes === 0) {
          clearInterval(myInterval);
        } else {
          setMinutes(minutes - 1);
          setSeconds(59);
        }
      }
    }, 1000);
    return () => {
      clearInterval(myInterval);
    };
  });

  return (
    <span>
      {minutes === 0 && seconds === 0 ? null : (
        <span>
          {' '}
          {minutes}:{seconds < 10 ? `0${seconds}` : seconds}
        </span>
      )}
    </span>
  );
};

function triggerTimers() {
  const result = computeTimes();
  if (result !== undefined) {
    const { remainingTime, timeBeforeWarning } = result;
    if (timeBeforeWarning > 0) {
      setTimeout(() => renderSessionExpirationWarning(), timeBeforeWarning);
    }
    if (remainingTime > 0) {
      setTimeout(renderSessionExpirated, remainingTime);
    }
  }
}

const computeRemainingTime = (expirationTime: number): number => expirationTime - Date.now();
const computeTimeBeforeWarning = (remainingTime: number): number =>
  remainingTime - timeBeforeWarningMs;
const computeTimes = (): { remainingTime: number; timeBeforeWarning: number } | undefined => {
  const expirationTime = getCookie('_oli_session_expiration_time');
  if (expirationTime != undefined) {
    const remainingTime = computeRemainingTime(expirationTime);
    const timeBeforeWarning = computeTimeBeforeWarning(remainingTime);
    return { remainingTime, timeBeforeWarning };
  }
  return undefined;
};

function renderSessionExpirationWarning() {
  const result = computeTimes();
  if (result !== undefined) {
    const minutes = Math.floor(result.remainingTime / 60000);
    const seconds = Math.floor((result.remainingTime % 60000) / 1000);
    renderComponent(
      'sessionExpirationContainerId',
      <SessionExpirationWarningComponent minutes={minutes} seconds={seconds} />,
    );
  }
}

function renderSessionExpirated() {
  unmountReactSessionExpContainer();
  renderComponent('sessionExpirationContainerId', <SessionTimeoutComponent />);
}

function renderComponent(id: string, component: ReactElement<any>) {
  ReactDOM.render(component, document.getElementById(id));
}

function getCookie(cname: string) {
  const name = cname + '=';
  const decodedCookie = decodeURIComponent(document.cookie);
  const ca = decodedCookie.split(';');
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return Number(c.substring(name.length, c.length));
    }
  }
  return undefined;
}
