import React, { useState, useEffect } from 'react';
import { CSSTransition } from 'react-transition-group';

export interface CreateAccountPopupProps {
  sectionSlug?: string;
}

export function CreateAccountPopup(props: CreateAccountPopupProps): JSX.Element {
  const [show, setShow] = useState(false);
  const [firstRender, setFirstRender] = useState(true);

  const onDismiss = () => {
    setShow(false);
    sessionStorage.setItem('accountPrompt', 'hide');
  }

  const onDontAskAgain = () => {
    setShow(false);
    localStorage.setItem('accountPrompt', 'hide');
  };

  const onBlurClick = (e: any) => {
    if (!e.createAccountPopupClick) {
      onDismiss()
      window.removeEventListener('click', onBlurClick);
    }
  }

  useEffect(() => {
    if (firstRender) {
      const showPref = sessionStorage.getItem('accountPrompt') != 'hide'
        && localStorage.getItem('accountPrompt') != 'hide'
      setShow(showPref);
      window.addEventListener('click', onBlurClick);
    }
    setFirstRender(false);
  });

  const onClick = (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    (e.nativeEvent as any).createAccountPopupClick = true;
  }

  return (
    <CSSTransition in={show} appear={true} timeout={300} unmountOnExit>
      <div className="create-account-popup" onClick={e => onClick(e)}>
        <div id="arrow"></div>

        <div className="d-flex flex-row">
          <h4>Welcome to Open and Free!</h4>
          <button type="button" className="btn close-btn close" aria-label="Close" onClick={() => onDismiss()}>
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
          You are viewing this course as a guest. Create an account or sign in to enroll in this course and track your progress.
          <div className="d-flex mt-4">
          <button className="btn btn-sm btn-link" onClick={() => onDontAskAgain()}>Don&apos;t ask again</button>
          <div className="flex-grow-1"></div>
          <a href={`/course/create_account?section=${props.sectionSlug}`} className="btn btn-sm btn-outline-primary ml-1">Create account</a>
          <a href={`/course/signin?section=${props.sectionSlug}`} className="btn btn-sm btn-primary ml-1">Sign in</a>
        </div>
      </div>
    </CSSTransition>
  );
}
