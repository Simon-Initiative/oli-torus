import React from 'react';
import { PreviewPanel } from './PreviewPanel';

interface Props {
  title?: string;
  children: React.ReactNode;
}

export const ReadonlyPanel: React.FC<Props> = ({ title, children }) => (
  <PreviewPanel title={title}>
    <div className="whitespace-pre-wrap">{children}</div>
  </PreviewPanel>
);
