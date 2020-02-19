import React, { useState } from 'react'

import { Node } from 'slate'
import { Editor } from './Editor';
import { ToolbarItem } from './interfaces';
import { ReactEditor } from 'slate-react';
import { LabelledTextEditor } from 'components/TextEditor';
import { commandDesc as imageCommandDesc } from './editors/Image';

const initialStem : Node[] = [
  {
    type: 'p',
    children: [ {text: 'This is the editor test view.'} ]
  },
  {
    type: 'img',
    src: 'https://source.unsplash.com/random',
    children: [ {text: ''} ],
    caption: 'this is the caption',
    alt: 'none'
  },
];

const initialValue : Node[] = [
  {
    type: 'p',
    children: [ {text: 'This is the editor test view.'} ]
  }
];

export type TestEditorProps = {

}

const toolbarItems : ToolbarItem[] = [
  {
    type: 'CommandDesc',
    icon: 'fas fa-list-ol',
    description: 'Ordered List',
    command: {
      execute: (e: ReactEditor) => console.log('o-list'),
      precondition: (e: ReactEditor) => true
    },
  },
  {
    type: 'CommandDesc',
    icon: 'fas fa-list-ul',
    description: 'Unordered List',
    command: {
      execute: (e: ReactEditor) => console.log('u-list'),
      precondition: (e: ReactEditor) => true
    },
  },
  {
    type: 'GroupDivider'
  },
  imageCommandDesc
]

export const TestEditor = (props: TestEditorProps) => {
  const [stem, setStem] = useState(initialStem);
  const [choice, setChoice] = useState(initialValue);

  return (
    <div>

      <p><b>Question Stem:</b></p>
      <Editor value={stem} onEdit={(value) => setStem(value)} toolbarItems={toolbarItems}/>

    </div>

  );
}
