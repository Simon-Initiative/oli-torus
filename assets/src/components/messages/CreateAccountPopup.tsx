import React, { useEffect, useState } from 'react';
import { CSSTransition } from 'react-transition-group';
import styles from './CreateAccountPopup.modules.scss';

export interface CreateAccountPopupProps {
  sectionSlug?: string;
}

export function CreateAccountPopup(props: CreateAccountPopupProps): JSX.Element {
  const [show, setShow] = useState(false);

  const onDismiss = () => {
    setShow(false);
    sessionStorage.setItem('createAccountPrompt', 'hide');
  };

  const onDontAskAgain = () => {
    setShow(false);
    localStorage.setItem('createAccountPrompt', 'hide');
  };

  const onBlurClick = (e: any) => {
    if (!e.createAccountPopupClick) {
      setShow(false);
      window.removeEventListener('click', onBlurClick);
    }
  };

  useEffect(() => {
    const showPref =
      sessionStorage.getItem('createAccountPrompt') != 'hide' &&
      localStorage.getItem('createAccountPrompt') != 'hide';
    setShow(showPref);
    window.addEventListener('click', onBlurClick);
  }, []);

  const onClick = (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    (e.nativeEvent as any).createAccountPopupClick = true;
  };

  return (
    <CSSTransition in={show} appear={true} timeout={300} unmountOnExit>
      <div className={styles.createAccountPopup} onClick={(e) => onClick(e)}>
        <div className={styles.arrow}></div>

        <div className="d-flex flex-row">
          <h4>Welcome to Open and Free!</h4>
        </div>
        <p>
          You are viewing this course as a guest. You can access course materials but your{' '}
          <b>progress will not be saved</b>.
        </p>

        <p>Create an account or sign in to enroll in this course and track your progress.</p>
        <div className="d-flex mt-4">
          <div className="btn-group">
            <button type="button" className="btn btn-sm btn-link" onClick={() => onDismiss()}>
              Maybe later
            </button>
            <button
              type="button"
              className="btn btn-sm btn-link dropdown-toggle dropdown-toggle-split"
              data-bs-toggle="dropdown"
              aria-haspopup="true"
              aria-expanded="false"
            >
              <span className="sr-only">Toggle Dropdown</span>
            </button>
            <div className="dropdown-menu">
              <button
                className="btn btn-sm btn-link dropdown-item text-left"
                onClick={() => onDontAskAgain()}
              >
                Don&apos;t ask again on this browser
              </button>
            </div>
          </div>

          <div className="flex-grow-1"></div>
          <a
            href={`/users/register?section=${props.sectionSlug}`}
            className="btn btn-sm btn-outline-primary ml-1"
          >
            Create account
          </a>
          <a
            href={`/users/log_in?section=${props.sectionSlug}`}
            className="btn btn-sm btn-primary ml-1"
          >
            Sign in
          </a>
        </div>
      </div>
    </CSSTransition>
  );
}
