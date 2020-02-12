import React, { useState } from 'react'

import { Node } from 'slate'
import { Editor } from './Editor';


const initialValue : Node[] = [
    {
        type: 'p',
        children: [ {text: 'This is the editor test view.'} ]
    }
];

export type TestEditorProps = {

}

export const TestEditor = (props: TestEditorProps) => {
  const [value, setValue] = useState(initialValue);

  return (
      <Editor value={value} onEdit={(value) => setValue(value)}/>
  );
}
