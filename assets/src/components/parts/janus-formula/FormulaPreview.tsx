import React, { useMemo } from 'react';
import { MathJax } from 'better-react-mathjax';

interface FormulaPreviewProps {
  input: string;
  altText?: string;
  className?: string;
}

const FormulaPreview: React.FC<FormulaPreviewProps> = ({ input, altText = '', className = '' }) => {
  const isMathML = input.trim().startsWith('<math');
  const isAlreadyRendered =
    input.includes('<mjx-container') || input.includes('MathJax') || input.includes('<math');

  const renderedContent = isMathML ? input : `\\(${input}\\)`;

  const renderPreview = useMemo(() => {
    if (!input) return null;
    if (isAlreadyRendered) {
      return <div aria-label={altText} dangerouslySetInnerHTML={{ __html: input }} />;
    }

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
