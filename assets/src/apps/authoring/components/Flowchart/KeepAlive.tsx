import React, { useCallback, useEffect, useState } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';

/*
  The KeepAlive component will send an api request to /authoring/keep-alive whenever we get a
  visibilityChange event. This will keep the user's session alive while they are on the page.
  If that call fails, it will display a modal error message suggesting the user refresh the page
  to log in again.

  In addition, it will send the keep alive request every 10 minutes.
*/

const TEN_MINUTES = 10 * 60 * 1000;

const KeepAlive: React.FC = () => {
  const [error, setError] = useState<string | null>(null);

  const keepAlive = useCallback(() => {
    fetch('/authoring/keep-alive', {
      method: 'GET',
      redirect: 'error',
    })
      .then((response) => {
        if (response.status !== 200) {
          throw new Error();
        }
      })
      .catch(() => {
        setError(
          'Your session has expired. Please refresh the page to log in or try again without logging in.',
        );
      });
  }, []);

  const reloadPage = useCallback(() => {
    window.location.reload();
  }, []);

  const tryAgain = useCallback(() => {
    setError(null);
    keepAlive();
  }, [keepAlive]);

  useEffect(() => {
    keepAlive();
  }, [keepAlive]);

  useEffect(() => {
    const interval = setInterval(keepAlive, TEN_MINUTES);
    return () => clearInterval(interval);
  }, [keepAlive]);

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden) {
        keepAlive();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [keepAlive]);

  return error ? (
    <AdvancedAuthoringModal show={true}>
      <Modal.Header>
        <h1>Error has occured</h1>
      </Modal.Header>
      <Modal.Body>{error}</Modal.Body>
      <Modal.Footer>
        <Button onClick={reloadPage} variant="secondary">
          Reload Page
        </Button>
        <Button onClick={tryAgain}>Try Again</Button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  ) : null;
};

export default KeepAlive;
