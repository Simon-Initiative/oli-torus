import React from 'react';
import { CommandDesc, Command } from 'components/editing/commands/interfaces';
import { Transforms } from 'slate';
import { useState } from 'react';
import { getQueryVariableFromString } from 'utils/params';
import { youtube } from 'data/content/model/elements/factories';

export type YouTubeCreationProps = {
  onDone: (src: string) => void;
};
const YouTubeCreation = (props: YouTubeCreationProps) => {
  const [src, setSrc] = useState('');

  return (
    <input
      style={{
        outline: 'none',
        color: 'rgba(0,0,0,0.84)',
        border: 'none',
        fontSize: '1rem',
        fontWeight: 400,
        lineHeight: '1.2rem',
        marginLeft: '12px',
      }}
      autoFocus
      type="text"
      placeholder="Paste a Youtube video link (e.g. youtube.com/watch?v=zHIIzcWqsP0) and press Enter"
      onChange={(e) => setSrc(e.target.value)}
      onKeyPress={(e) => e.key === 'Enter' && props.onDone(src)}
    />
  );
};

const command: Command = {
  execute: (_context, editor, src: string) => {
    const at = editor.selection;
    if (!at) return;

    const hasParams = src.includes('?');

    if (hasParams) {
      const queryString = src.substr(src.indexOf('?') + 1);
      src = getQueryVariableFromString('v', queryString);
    } else if (src.indexOf('/youtu.be/') !== -1) {
      src = src.substr(src.lastIndexOf('/') + 1);
    }

    Transforms.insertNodes(editor, youtube(src), { at });
  },
  precondition: (_editor) => {
    return true;
  },
  // eslint-disable-next-line react/display-name
  obtainParameters: (_ctx, _ed, onDone, _onCancel) => <YouTubeCreation onDone={onDone} />,
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'play_circle_filled',
  description: () => 'YouTube',
  command,
};
