import React, { useCallback, useEffect } from 'react';
import { sanitizeMathML } from '../../utils/mathmlSanitizer';

/**
 * Two components to render some markup for MathJax and then call MathJax to actually typeset it.
 * These are required in any case when the markup is added to the dom after the initial render so
 * the formula gets typeset properly.
 *
 * Examples:
 *  <MathJaxMathMLFormula src="<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>" inline={false} />
 *  <MathJaxLatexFormula src="x^2 + y^2" inline={false} /> // Note: Do NOT include the escape characters in src.
 */

const cssClass = (inline: boolean) => (inline ? 'formula-inline' : 'formula');

/* istanbul ignore next */
let lastPromise = window?.MathJax?.startup?.promise;
/* istanbul ignore next */
if (!lastPromise) {
  typeof jest === 'undefined' &&
    console.warn('Load the MathJax script before this one or unpredictable rendering might occur.');
  lastPromise = Promise.resolve();
}

/**
 * React hook that returns a ref for you to put on your span that containst the mathjax markup.
 * After that, the hook will manage calling the MathJax typesetPromise on your element whenever
 * the src changes.
 *
 * @param src The mathml or latex source, used to detect changes and re-render
 * @returns ref = a ref callback to be used on your span
 */
const useMathJax = (src: string) => {
  const ref = useCallback(
    (node: HTMLDivElement) => {
      if (node) {
        // According to the mathJax docs, you should only let 1 instance typeset at a time, so
        // that's what the promise chain here does.
        lastPromise = lastPromise.then(() => window.MathJax.typesetPromise([node]));
      }
    },
    [src],
  );

  return ref;
};

interface MathJaxFormulaProps {
  src: string;
  inline: boolean;
  style?: Record<string, string>;
  onClick?: () => void;
}

export const MathJaxMathMLFormula: React.FC<MathJaxFormulaProps> = ({
  src,
  inline,
  style,
  onClick,
}) => {
  const ref = useMathJax(src);
  return (
    <span
      onClick={onClick}
      style={style}
      className={cssClass(inline)}
      ref={ref}
      dangerouslySetInnerHTML={{ __html: sanitizeMathML(src) }}
    />
  );
};

MathJaxMathMLFormula.defaultProps = { style: {} };

export const MathJaxLatexFormula: React.FC<MathJaxFormulaProps> = ({
  src,
  inline,
  style,
  onClick,
}) => {
  const ref = useMathJax(src);
  const wrapped = inline ? `\\(${src}\\)` : `\\[${src}\\]`;

  return (
    <span onClick={onClick} style={style} className={cssClass(inline)} ref={ref}>
      {wrapped}
    </span>
  );
};

MathJaxLatexFormula.defaultProps = { style: {} };

// Add some types to window to satisfy our minimal needs instead of loading the full mathjax type definitions.
interface MathJaxMinimal {
  typesetPromise: (nodes: HTMLElement[]) => Promise<void>;
  tex2mml: (tex: string) => string;
  startup: {
    promise: Promise<void>;
    load?: () => void;
  };
}

declare global {
  interface Window {
    MathJax: MathJaxMinimal;
  }
}
