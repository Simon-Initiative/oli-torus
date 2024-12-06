import React from 'react';
import { Alert, Button } from 'react-bootstrap';

interface ReadOnlyWarningProps {
  isAttemptDisableReadOnlyFailed: boolean;
  alertSeverity: string;
  dismissReadOnlyWarning: (p: { attemptEdit: boolean }) => void;
  url: string;
  windowName: string;
}

export const ReadOnlyWarning: React.FC<ReadOnlyWarningProps> = ({
  isAttemptDisableReadOnlyFailed,
  alertSeverity,
  dismissReadOnlyWarning,
  url,
  windowName,
}) => (
  <div className="mt-2">
    <Alert variant={alertSeverity}>
      <Alert.Heading>Opening in Read-Only Mode</Alert.Heading>
      {!isAttemptDisableReadOnlyFailed && (
        <p>
          You are about to open this page in read-only mode. You are able to view the contents of
          this page, but any changes you make will not be saved. You may instead attempt to open in
          editing mode, or open a preview of the page.
        </p>
      )}
      {isAttemptDisableReadOnlyFailed && (
        <p>
          Unfortunately, we were unable to disable read-only mode. Another author currently has the
          page locked for editing. Please try again later. In the meantime, you may continue in Read
          Only mode or open a preview of the page.
        </p>
      )}
      <hr />
      <div style={{ textAlign: 'center' }}>
        <Button
          variant={`outline-${alertSeverity}`}
          className="text-dark"
          onClick={() => dismissReadOnlyWarning({ attemptEdit: false })}
        >
          Continue In Read-Only Mode
        </Button>{' '}
        {!isAttemptDisableReadOnlyFailed && (
          <>
            <Button
              variant={`outline-${alertSeverity}`}
              className="text-dark"
              onClick={() => dismissReadOnlyWarning({ attemptEdit: true })}
            >
              Open In Edit Mode
            </Button>{' '}
          </>
        )}
        <Button
          variant={`outline-${alertSeverity}`}
          className="text-dark"
          onClick={() => window.open(url, windowName)}
        >
          Open Preview <i className="fas fa-external-link-alt ml-1"></i>
        </Button>
      </div>
    </Alert>
  </div>
);
