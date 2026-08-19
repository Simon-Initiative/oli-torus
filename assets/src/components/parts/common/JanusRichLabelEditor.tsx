import React, { useEffect, useMemo } from 'react';
import ReactQuill from 'react-quill';

export const QUILL_SNOW_CSS_ID = 'quill-snow-css-janus-rich-label';

export const JANUS_RICH_LABEL_QUILL_FORMATS = ['bold', 'italic', 'script'];

export const JANUS_RICH_LABEL_QUILL_MODULES = {
  toolbar: [
    ['bold', 'italic'],
    [{ script: 'sub' }, { script: 'super' }],
  ],
};

export interface JanusRichLabelEditorProps {
  labelledBy?: string;
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
  minHeight?: number;
  className?: string;
}

/**
 * Inline Quill editor for short Janus labels (sup/sub/bold/italic).
 * Used directly in forms or wrapped by JanusRichLabelEditorModal.
 */
export const JanusRichLabelEditor: React.FC<JanusRichLabelEditorProps> = ({
  labelledBy,
  value,
  onChange,
  disabled = false,
  minHeight = 120,
  className,
}) => {
  useEffect(() => {
    if (typeof document === 'undefined') {
      return;
    }
    if (!document.getElementById(QUILL_SNOW_CSS_ID)) {
      const link = document.createElement('link');
      link.id = QUILL_SNOW_CSS_ID;
      link.rel = 'stylesheet';
      link.href = 'https://cdn.quilljs.com/1.3.6/quill.snow.css';
      document.head.appendChild(link);
    }
  }, []);

  const modules = useMemo(() => JANUS_RICH_LABEL_QUILL_MODULES, []);

  return (
    <div
      className={`janus-rich-label-editor-quill${className ? ` ${className}` : ''}`}
      role="group"
      aria-labelledby={labelledBy}
    >
      <ReactQuill
        theme="snow"
        value={value}
        onChange={onChange}
        modules={modules}
        formats={JANUS_RICH_LABEL_QUILL_FORMATS}
        readOnly={disabled}
        style={{ minHeight }}
      />
    </div>
  );
};

export default JanusRichLabelEditor;
