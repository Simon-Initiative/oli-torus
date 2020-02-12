import React, { useState } from 'react'

import { Node } from 'slate'
import { Editor, ToolbarItem } from './Editor';
import { ReactEditor } from 'slate-react';
import { Command, CommandDesc } from './interfaces';

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
  { 
    type: 'CommandDesc', 
    icon: 'fas fa-image', 
    description: 'Image',
    command: { 
      execute: (e: ReactEditor) => console.log('u-image'), 
      precondition: (e: ReactEditor) => true 
    }, 
  },
]

export const TestEditor = (props: TestEditorProps) => {
  const [value, setValue] = useState(initialValue);

  return (
    <Editor value={value} onEdit={(value) => setValue(value)} toolbarItems={toolbarItems}/>
  );
}
