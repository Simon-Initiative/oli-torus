import React, { useState } from 'react';

import { Node } from 'slate';
import { Editor } from './Editor';
import { ToolbarItem } from './interfaces';
import { commandDesc as imageCommandDesc } from './editors/Image';
import { olCommandDesc as olCmd, ulCommanDesc as ulCmd, olCommandDesc } from './editors/Lists';

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
  olCmd,
  ulCmd,
  {
    type: 'GroupDivider',
  },
  imageCommandDesc,
];

export const TestEditor = (props: TestEditorProps) => {
  const [stem, setStem] = useState(initialStem);
  const [choice, setChoice] = useState(initialValue);

  return (
    <div>

      <p><b>Question Stem:</b></p>
      <Editor value={stem} onEdit={value => setStem(value)} toolbarItems={toolbarItems} />

    </div>

  );
};
