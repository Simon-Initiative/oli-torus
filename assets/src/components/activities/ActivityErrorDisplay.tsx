import React from 'react';
import { Alert } from 'components/misc/Alert';

interface Props {
  error: string | null;
  children: React.ReactNode;
}

const ErrorContainer: React.FC<Props> = ({ children, error }) => {
  const className = error ? 'border-l-4 mb-4 py-4 pl-4 border-red-200' : '';
  return <div className={className}>{children}</div>;
};

export const ActivityErrorDisplay: React.FC<Props> = ({ error, children }) => {
  return (
    <ErrorContainer error={error}>
      {children}

      {error && (
        <>
          <br />
          <Alert variant="error">{error}</Alert>
        </>
      )}
    </ErrorContainer>
  );
};
