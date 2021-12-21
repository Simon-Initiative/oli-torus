import React from 'react';
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

export const Messages: { [type: string]: React.FC<Message> } = {
  [DiagnosticTypes.PATTERN]: PatternMessage,
  [DiagnosticTypes.DUPLICATE]: DupeMessage,
  [DiagnosticTypes.BROKEN]: BrokenMessage,
};

export const DiagnosticMessage: React.FC<Message> = (props) => {
  const { problem } = props;
  const Message = Messages[problem.type];

  return <Message {...props} />;
};

export default DiagnosticMessage;
