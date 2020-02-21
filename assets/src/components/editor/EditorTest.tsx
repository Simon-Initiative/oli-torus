import React, { useState } from 'react';

import { Node } from 'slate';
import { Editor } from './Editor';
import { ToolbarItem } from './interfaces';
import { commandDesc as imageCommandDesc } from './editors/Image';
import { olCommandDesc as olCmd, ulCommanDesc as ulCmd } from './editors/Lists';
import { commandDesc as youtubeCommandDesc } from './editors/YouTube';
import { commandDesc as quoteCommandDesc } from './editors/Blockquote';
import { commandDesc as audioCommandDesc } from './editors/Audio';

const initialStem: Node[] = [
  {
    type: 'p',
    children: [{ text: 'This is the editor test view.' }],
  },
  {
    type: 'img',
    src: 'https://source.unsplash.com/random',
    children: [{ text: '' }],
    caption: 'this is the caption',
    alt: 'none',
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
  audioCommandDesc,
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
