import React from 'react';
import { MathJaxLatexFormula, MathJaxMathMLFormula } from './MathJaxFormula';

export const Formula: React.FC<{
  id: string;
  type?: string;
  subtype: string;
  src: string;
  onClick?: () => void;
  style?: Record<string, string>;
  formulaAltText?: string;
}> = ({ id, type, subtype, src, style, onClick, formulaAltText = '' }) => {
  switch (subtype) {
    case 'latex':
      return (
        <MathJaxLatexFormula
          id={id}
          onClick={onClick}
          style={style}
          inline={type === 'formula_inline'}
          src={src}
          formulaAltText={formulaAltText}
        />
      );
    case 'mathml':
      return (
        <MathJaxMathMLFormula
          id={id}
          onClick={onClick}
          style={style}
          inline={type === 'formula_inline'}
          src={src}
          formulaAltText={formulaAltText}
        />
      );
    default:
      return <div>Error: Unknown formula type {subtype}</div>;
  }
};

Formula.defaultProps = {
  style: {},
  type: 'formula',
};
