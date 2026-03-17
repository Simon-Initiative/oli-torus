import React, { CSSProperties, useEffect } from 'react';
import { AIIcon } from 'components/misc/AIIcon';
import { AuthorPartComponentProps } from '../types/parts';
import { AITriggerModel } from './schema';

const AITriggerAuthor: React.FC<AuthorPartComponentProps<AITriggerModel>> = ({
  id,
  model,
  onReady,
}) => {
  useEffect(() => {
    onReady({ id });
  }, [id, onReady]);

  const { width = 56, height = 56, launchMode = 'click', prompt } = model;
  const styles: CSSProperties = {
    width,
    minHeight: height,
    border: '1px dashed #0165DA',
    borderRadius: 12,
    backgroundColor: '#F4F9FF',
    color: '#0F172A',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    padding: '10px 12px',
    cursor: 'move',
    textAlign: 'left',
  };

  return (
    <div data-janus-type={tagName} style={styles}>
      <AIIcon size="sm" />
      <div style={{ lineHeight: 1.2 }}>
        <div style={{ fontSize: 12, fontWeight: 600 }}>DOT AI Activation Point</div>
        <div style={{ fontSize: 11, color: '#475569' }}>
          {launchMode === 'auto' ? 'Auto Activated' : 'User Activated'}
          {prompt?.trim() ? '' : ' - Add prompt'}
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-ai-trigger';

export default AITriggerAuthor;
