import React, { ReactNode } from 'react';
import { ResetButtonConnected } from './reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from './submit_button/SubmitButtonConnected';

interface Props {
  onReset: () => void;
  submitDisabled?: boolean;
  submitLabel?: string;
}

export const SubmitResetConnected: React.FC<Props> = ({ onReset, submitDisabled, submitLabel }) => {
  return (
    <SubmitResetLayout
      submitButton={
        <SubmitButtonConnected
          hideOnSubmitted={false}
          disabled={submitDisabled}
          label={submitLabel}
        />
      }
      resetButton={<ResetButtonConnected hideBeforeSubmit={false} onReset={onReset} />}
    />
  );
};

interface SubmitResetLayoutProps {
  submitButton: ReactNode;
  resetButton: ReactNode;
}
export const SubmitResetLayout: React.FC<SubmitResetLayoutProps> = ({
  submitButton,
  resetButton,
}) => {
  return (
    <Row>
      <Col>{submitButton}</Col>
      <Col>{resetButton}</Col>
    </Row>
  );
};

const Col: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="inline-block">{children}</div>
);
const Row: React.FC<{ children: ReactNode }> = ({ children }) => (
  <div className="flex justify-between flex-row w-auto">{children}</div>
);
