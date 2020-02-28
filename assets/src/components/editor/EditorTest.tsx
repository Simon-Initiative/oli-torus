import React, { useState } from 'react';

import { Node } from 'slate';
import { Editor } from './Editor';
import { ToolbarItem } from './interfaces';
import { commandDesc as imageCommandDesc } from './editors/Image';
import { olCommandDesc as olCmd, ulCommanDesc as ulCmd } from './editors/Lists';
import { commandDesc as youtubeCommandDesc } from './editors/YouTube';
import { commandDesc as quoteCommandDesc } from './editors/Blockquote';
import { commandDesc as audioCommandDesc } from './editors/Audio';
import { commandDesc as codeCommandDesc } from './editors/Code';
import { commandDesc as tableCommandDesc } from './editors/Table';

const initialStem: Node[] = [
  {
    type: 'p',
    children: [{ text: 'This is the editor test view.' }],
  },
  {
    type: 'p',
    children: [
      { text: 'Here is a sentence.' },
    ],
  },

];

const toolbarItems: ToolbarItem[] = [
  quoteCommandDesc,
  {
    type: 'GroupDivider',
  },
  olCmd,
  ulCmd,
  {
    type: 'GroupDivider',
  },
  imageCommandDesc,
  youtubeCommandDesc,
  audioCommandDesc,
  {
    type: 'GroupDivider',
  },
  codeCommandDesc,
  tableCommandDesc,
];

export const TestEditor = () => {
  const [stem, setStem] = useState(initialStem);

  return (
    <div>

      <p><b>Question Stem:</b></p>
      <Editor
        value={stem}
        onEdit={(value) => {
          setStem(value);
        }}
        toolbarItems={toolbarItems} />

    </div>

  );
};
