import React from 'react';

interface Props {
  title?: string;
  children: React.ReactNode;
}

export const PreviewPanel: React.FC<Props> = ({ title, children }) => (
  <section className="rounded-lg border border-gray-200 bg-gray-50 p-4">
    {title && <h4 className="mb-3 text-sm font-semibold text-gray-700">{title}</h4>}
    <div className="text-sm text-gray-700">{children}</div>
  </section>
);
