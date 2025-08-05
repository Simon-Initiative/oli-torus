import React, { useCallback } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { PointMarkerContext, maybePointMarkerAttr } from 'data/content/utils';
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

const getGlobalLastPromise = () => {
  /* istanbul ignore next */
  let lastPromise = window?.MathJax?.startup?.promise;
  /* istanbul ignore next */
  if (!lastPromise) {
    console.info('NO LAST PROMISE');
    typeof jest === 'undefined' &&
      console.warn(
        'Load the MathJax script before this one or unpredictable rendering might occur.',
      );
    lastPromise = Promise.resolve();
  }
  return lastPromise;
};

const setGlobalLastPromise = (promise: Promise<any>) => {
  window.MathJax.startup.promise = promise;
};

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
        let lastPromise = getGlobalLastPromise();
        lastPromise = lastPromise.then(() => window.MathJax.typesetPromise([node]));
        setGlobalLastPromise(lastPromise);
      }
    },
    [src],
  );

  return ref;
};

interface MathJaxFormulaProps {
  id: string;
  src: string;
  inline: boolean;
  style?: Record<string, string>;
  pointMarkerContext?: PointMarkerContext;
  onClick?: () => void;
  formulaAltText?: string;
}

export const MathJaxMathMLFormula: React.FC<MathJaxFormulaProps> = ({
  id,
  src,
  inline,
  style,
  pointMarkerContext,
  onClick,
  formulaAltText = '',
}) => {
  const ref = useMathJax(src);
  return (
    <span
      aria-label={formulaAltText}
      onClick={onClick}
      style={style}
      className={cssClass(inline)}
      ref={ref}
      dangerouslySetInnerHTML={{ __html: sanitizeMathML(src) }}
      {...maybePointMarkerAttr({ id: id } as ContentModel.FormulaBlock, pointMarkerContext)}
    />
  );
};

MathJaxMathMLFormula.defaultProps = { style: {} };

// MathJax 3.0 only handles \\ as newlines if wrapped in \displaylines{..}
const fixNL = (s: string) =>
  // look for double slash followed by any other character to avoid matching at end
  s.match(/\\\\./) && !s.startsWith('\\begin{array}') && !s.startsWith('\\displaylines')
    ? `\\displaylines{${s}}`
    : s;

export const MathJaxLatexFormula: React.FC<MathJaxFormulaProps> = ({
  id,
  src,
  inline,
  style,
  onClick,
  pointMarkerContext,
  formulaAltText = '',
}) => {
  const ref = useMathJax(src);
  const fixed = fixNL(src);
  const wrapped = inline ? `\\(${fixed}\\)` : `\\[${fixed}\\]`;

  return (
    <span
      aria-label={formulaAltText}
      onClick={onClick}
      style={style}
      className={cssClass(inline)}
      ref={ref}
      {...maybePointMarkerAttr({ id: id } as ContentModel.FormulaBlock, pointMarkerContext)}
    >
      {wrapped}
    </span>
  );
};

MathJaxLatexFormula.defaultProps = { style: {} };

// Add some types to window to satisfy our minimal needs instead of loading the full mathjax type definitions.
interface MathJaxMinimal {
  typesetPromise: (nodes: HTMLElement[]) => Promise<void>;
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
