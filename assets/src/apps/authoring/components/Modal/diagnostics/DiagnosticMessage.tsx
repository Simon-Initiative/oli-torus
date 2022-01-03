import React, { Fragment } from 'react';
import { DiagnosticTypes } from './DiagnosticTypes';

export interface Message {
  problem: any;
}

export const DupeMessage: React.FC<Message> = ({ problem }: Message) => (
  <span>
    A {problem.item.type} component with the ID &quot;
    <strong>{problem.item.id} </strong> &quot;located on
  </span>
);

export const PatternMessage: React.FC<Message> = ({ problem }: Message) => (
  <span>
    A {problem.item.type} component with the ID &quot;
    <strong>{problem.item.id}</strong>&quot;, has problematic characters. It is best to use
    alphanumeric characters only.
  </span>
);

export const BrokenMessage: React.FC<Message> = ({ problem }: Message) => (
  <span>
    A {problem.item.type} component with the ID &quot;
    <strong>{problem.item.id}</strong>&quot;, has a broken path.
  </span>
);

export const DiagnosticMessage: React.FC<Message> = (props) => {
  const { problem } = props;
  const { type = DiagnosticTypes.DEFAULT } = problem;

  let action;
  switch (type) {
    case DiagnosticTypes.DUPLICATE:
      action = <DupeMessage {...props} />;
      break;
    case DiagnosticTypes.PATTERN:
      action = <PatternMessage {...props} />;
      break;
    case DiagnosticTypes.BROKEN:
      action = <BrokenMessage {...props} />;
      break;
    default:
      action = <Fragment>No fix defined.</Fragment>;
      break;
  }
  return <Fragment>{action}</Fragment>;
};

export default DiagnosticMessage;
