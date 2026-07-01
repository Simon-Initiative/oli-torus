import React from 'react';

interface Props {
  title?: string;
  children: React.ReactNode;
  tone?: 'default' | 'feedback';
}

export const PreviewPanel: React.FC<Props> = ({ title, children, tone = 'default' }) => (
  <section
    className={`rounded-md border border-Border-border-default ${
      tone === 'feedback'
        ? 'bg-Specially-Tokens-Fill-fill-input-focused px-4 py-2'
        : 'bg-Surface-surface-secondary-muted px-4 py-3'
    }`}
  >
    {title && <h4 className="mb-2 text-base font-medium text-Text-text-high">{title}</h4>}
    <div
      className={`text-base leading-6 text-Text-text-high [&_.content_p]:my-0 ${
        tone === 'feedback' ? 'font-medium' : 'font-normal'
      }`}
    >
      {children}
    </div>
  </section>
);
