import { DiagnosticTypes } from './DiagnosticTypes';
import { FixBrokenPathButton } from './FixBrokenPathButton';
import { FixIdButton } from './FixIdButton';
import { FixTargetButton } from './FixTargetButton';
import { SolutionProps } from './SolutionProps';
import React, { Fragment } from 'react';

export const DiagnosticSolution: React.FC<SolutionProps> = (props: SolutionProps): JSX.Element => {
  const { type = DiagnosticTypes.DEFAULT } = props;

  let action;
  switch (type) {
    case DiagnosticTypes.DUPLICATE:
      action = <FixIdButton {...props} />;
      break;
    case DiagnosticTypes.PATTERN:
      action = <FixIdButton {...props} />;
      break;
    case DiagnosticTypes.BROKEN:
      action = <FixBrokenPathButton {...props} />;
      break;
    case DiagnosticTypes.INVALID_TARGET_COND:
    case DiagnosticTypes.INVALID_TARGET_INIT:
    case DiagnosticTypes.INVALID_TARGET_MUTATE:
      action = <FixTargetButton {...props} />;
      break;
    case DiagnosticTypes.INVALID_VALUE:
    case DiagnosticTypes.INVALID_EXPRESSION_VALUE:
    case DiagnosticTypes.INVALID_EXPRESSION:
    case DiagnosticTypes.INVALID_OWNER_INIT:
    case DiagnosticTypes.INVALID_OWNER_CONDITION:
    case DiagnosticTypes.INVALID_OWNER_MUTATE:
      action = <FixIdButton {...props} />;
      break;
    default:
      action = <Fragment>No fix defined.</Fragment>;
      break;
  }
  return <Fragment>{action}</Fragment>;
};

export default DiagnosticSolution;
