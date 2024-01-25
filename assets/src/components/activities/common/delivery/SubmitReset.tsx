import React, { ReactNode } from 'react';
import { ResetButtonConnected } from './reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from './submit_button/SubmitButtonConnected';

interface Props {
  onReset: () => void;
}

export const SubmitReset: React.FC<Props> = ({ onReset }) => {
  return (
    <Row>
      <Col>
        <SubmitButtonConnected hideOnSubmitted={false} />
      </Col>
      <Col>
        <ResetButtonConnected hideBeforeSubmit={false} onReset={onReset} />
      </Col>
    </Row>
  );
};

const Col: React.FC<{ children: ReactNode }> = ({ children }) => <div className='inline-block'>{children}</div>;
const Row: React.FC<{ children: ReactNode }> = ({ children }) => <div className='flex justify-between flex-row w-auto'>{children}</div>;
