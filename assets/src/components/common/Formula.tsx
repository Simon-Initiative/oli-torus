import React from 'react';
import { MathJaxLatexFormula, MathJaxMathMLFormula } from './MathJaxFormula';

/**
 * ⚠️ IMPORTANT: This component is also used in the Formula component within both
 * Simple Author (Flowchart) and Advanced Author, specifically for rendering LaTeX and MathML formulas.
 *
 * Any changes made here must be thoroughly tested in both authoring contexts
 * to ensure correct rendering and to prevent regressions or unexpected behavior.
 */
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
