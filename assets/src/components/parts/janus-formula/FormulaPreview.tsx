import React, { useMemo } from 'react';
import { MathJax } from 'better-react-mathjax';

interface FormulaPreviewProps {
  input: string;
  altText?: string;
  className?: string;
}

const FormulaPreview: React.FC<FormulaPreviewProps> = ({ input, altText = '', className = '' }) => {
  // Check if the input is in MathML format by inspecting its starting tag
  const isMathML = input.trim().startsWith('<math');

  // Determine if the input has already been rendered by MathJax (to avoid re-rendering it)
  const isAlreadyRendered =
    input.includes('<mjx-container') || // MathJax's rendered container
    input.includes('MathJax') || // Any MathJax-related markup
    input.includes('<math'); // MathML input

  // If it's MathML, use it as-is. Otherwise, wrap the raw LaTeX input in inline math delimiters (for MathJax to render)
  const renderedContent = isMathML ? input : `\\(${input}\\)`;

  // Memoize the rendering logic to avoid unnecessary re-renders
  const renderPreview = useMemo(() => {
    // If there's no input at all, render nothing
    if (!input) return null;

    // If input is already rendered HTML (from MathJax), insert it directly without re-wrapping in <MathJax>
    if (isAlreadyRendered) {
      return <div aria-label={altText} dangerouslySetInnerHTML={{ __html: input }} />;
    }

    // Otherwise, wrap the content in <MathJax> so it gets rendered properly
    return (
      <MathJax>
        <div aria-label={altText} dangerouslySetInnerHTML={{ __html: renderedContent }} />
      </MathJax>
    );
  }, [input, altText]);

  return (
    <div
      className={`mt-4 ${className}`}
      style={{
        fontSize: '20px',
      }}
    >
      {renderPreview}
    </div>
  );
};

export default FormulaPreview;
