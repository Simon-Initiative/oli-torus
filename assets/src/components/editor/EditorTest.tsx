import React, { useState } from 'react';

import { Node } from 'slate';
import { Editor } from './Editor';
import { ToolbarItem } from './interfaces';
import { commandDesc as imageCommandDesc } from './editors/Image';
import { olCommandDesc as olCmd, ulCommanDesc as ulCmd } from './editors/Lists';
import { commandDesc as youtubeCommandDesc } from './editors/YouTube';
import { commandDesc as quoteCommandDesc } from './editors/Blockquote';

const initialStem: Node[] = [
  {
    type: 'p',
    children: [{ text: 'This is the editor test view.' }],
  },
  {
    type: 'p',
    children: [
      { text: 'Try to visit ' },
      {
        type: 'a', href: 'https://www.google.com', target: '_blank',
        children: [{ text: 'google' }]
      },
    ],
  },

];

const initialValue: Node[] = [
  {
    type: 'p',
    children: [{ text: 'This is the editor test view.' }],
  },
];

export type TestEditorProps = {

};

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
];

export const TestEditor = (props: TestEditorProps) => {
  const [stem, setStem] = useState(initialStem);
  const [choice, setChoice] = useState(initialValue);

  return (
    <div>

      <p><b>Question Stem:</b></p>
      <Editor value={stem} onEdit={(value) => {
        // const s = JSON.stringify(value, null, 2);
        // console.log(s);
        setStem(value);
      }} toolbarItems={toolbarItems} />

    </div>

  );
};
