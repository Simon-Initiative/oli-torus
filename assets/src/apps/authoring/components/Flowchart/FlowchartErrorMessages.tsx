// Adding better error handling to flowchart-mode
// We can turn this into a general advanced-authoring error, but for now sticking to flowchart-mode
import React, { useCallback } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { clearError, selectApiError } from '../../store/flowchart/flowchart-slice';
import { AdvancedAuthoringModal } from '../AdvancedAuthoringModal';
import { Button, Modal } from 'react-bootstrap';
import { useToggle } from '../../../../components/hooks/useToggle';

export const FlowchartErrorDisplay = () => {
  const error = useSelector(selectApiError);
  const dispatch = useDispatch();
  const [fullError, , showFullError] = useToggle(false);
  const onClose = useCallback(() => {
    dispatch(clearError());
  }, [dispatch]);

  if (!error) {
    return null;
  }
  const { error: errorString, ...rest } = error;

  return (
    <AdvancedAuthoringModal show={true} size="lg">
      <Modal.Header closeButton={false}>
        <h1>{error.title}</h1>
      </Modal.Header>
      <Modal.Body>
        <p>{error.message}</p>
        {fullError || (
          <Button variant="link" onClick={showFullError}>
            View full error
          </Button>
        )}
        {fullError && (
          <pre className="max-h-52 overflow-auto">
            {errorString?.split(/\r?\\n/).map((line, i) => {
              return (
                <span key={i}>
                  {line}

                  <br />
                </span>
              );
            })}
            {JSON.stringify(rest, null, 2)}
          </pre>
        )}
      </Modal.Body>
      <Modal.Footer>
        <button onClick={onClose} className="btn btn-primary">
          Close
        </button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};
