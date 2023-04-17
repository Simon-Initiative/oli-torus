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

export const ValueUndefined: React.FC<Message> = ({ problem }: Message) => (
  <span>
    The &quot;
    <strong>{problem?.item?.rule?.name}</strong>&quot; rule is missing a condition value.
  </span>
);

export const InvalidExpressionValue: React.FC<Message> = ({ problem }: Message) => (
  <span>
    {problem?.item?.rule?.name ? (
      <span>
        The &quot;
        <strong>{problem?.item?.rule?.name}</strong>&quot; rule has invalid expression.
      </span>
    ) : (
      <span>A rule in the initial state has an invalid expression.</span>
    )}
  </span>
);

export const InvalidPartExpressionValue: React.FC<Message> = ({ problem }: Message) => (
  <span>
    The &quot;
    <strong>{problem?.item?.part?.id}</strong>&quot; component has invalid expression &nbsp;
    {problem.item.message && <span>in {problem.item.message}</span>}
  </span>
);

export const InvalidMutateTarget: React.FC<Message> = ({ problem }: Message) => (
  <span>
    The &quot;
    <strong>{problem?.item?.name}</strong>&quot; rule, has an invalid action target (
    <strong>{problem?.item?.action.params.target}</strong>).
  </span>
);

export const InvalidCondTarget: React.FC<Message> = ({ problem }: Message) => (
  <span>
    The &quot;
    <strong>{problem?.item?.rule?.name}</strong>&quot; rule has an invalid condition target (
    <strong>{problem?.item?.condition?.fact}</strong>).
  </span>
);

export const InvalidInitStateTarget: React.FC<Message> = ({ problem }: Message) => (
  <span>
    A rule in the initial state has an invalid component target (
    <strong>{problem?.item?.fact?.target}</strong>).
  </span>
);

export const InvalidOwnerInitState: React.FC<Message> = ({ problem }: Message) => (
  <span>
    Invalid init state: problem with owner target (<strong>{problem?.item?.fact?.value}</strong>).
  </span>
);

export const InvalidOwnerCondition: React.FC<Message> = ({ problem }: Message) => (
  <span>
    Invalid condition: problem with owner target in (<strong>{problem?.item?.rule?.name}</strong>).
  </span>
);

export const InvalidOwnerMutateState: React.FC<Message> = ({ problem }: Message) => (
  <span>
    Invalid mutate state: problem with owner target in (<strong>{problem?.item?.rule?.name}</strong>
    ).
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
    case DiagnosticTypes.INVALID_TARGET_COND:
      action = <InvalidCondTarget {...props} />;
      break;
    case DiagnosticTypes.INVALID_TARGET_INIT:
      action = <InvalidInitStateTarget {...props} />;
      break;
    case DiagnosticTypes.INVALID_TARGET_MUTATE:
      action = <InvalidMutateTarget {...props} />;
      break;
    case DiagnosticTypes.INVALID_VALUE:
      action = <ValueUndefined {...props} />;
      break;
    case DiagnosticTypes.INVALID_EXPRESSION_VALUE:
      action = <InvalidExpressionValue {...props} />;
      break;
    case DiagnosticTypes.INVALID_EXPRESSION:
      action = <InvalidPartExpressionValue {...props} />;
      break;
    case DiagnosticTypes.INVALID_OWNER_INIT:
      action = <InvalidOwnerInitState {...props} />;
      break;
    case DiagnosticTypes.INVALID_OWNER_CONDITION:
      action = <InvalidOwnerCondition {...props} />;
      break;
    case DiagnosticTypes.INVALID_OWNER_MUTATE:
      action = <InvalidOwnerMutateState {...props} />;
      break;
    default:
      action = <Fragment>No fix defined.</Fragment>;
      break;
  }
  return <Fragment>{action}</Fragment>;
};

export default DiagnosticMessage;
