import React, { useMemo, useRef } from 'react';
import { MathJax } from 'better-react-mathjax';

interface FormulaPreviewProps {
  input: string;
  altText?: string;
  className?: string;
}

const FormulaPreview: React.FC<FormulaPreviewProps> = ({ input, altText = '', className = '' }) => {
  const isMathML = input.trim().startsWith('<math');
  const renderedContent = isMathML ? input : `\\(${input}\\)`;
  const containerRef = useRef<HTMLDivElement>(null);

  const renderPreview = useMemo(() => {
    console.log('useMemo->useMemo', { input });
    return (
      <MathJax>
        <div dangerouslySetInnerHTML={{ __html: renderedContent }} aria-label={altText} />
      </MathJax>
    );
  }, [input]);

  return (
    <div className={`mt-4 ${className}`} ref={containerRef}>
      {renderPreview}
    </div>
  );
};

export default FormulaPreview;
