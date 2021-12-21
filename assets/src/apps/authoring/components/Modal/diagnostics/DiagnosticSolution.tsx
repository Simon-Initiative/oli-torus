import React, { Fragment } from 'react';

import { DiagnosticTypes } from './DiagnosticTypes';
import FixIdButton from './FixIdButton';
import { FixBrokenPathButton } from './FixBrokenPathButton';
import { SolutionProps } from './SolutionProps';

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
    default:
      action = <Fragment />;
      break;
  }
  return <Fragment>{action}</Fragment>;
};

export default DiagnosticSolution;
