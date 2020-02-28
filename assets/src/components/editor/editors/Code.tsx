import React from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';

const command: Command = {
  execute: (editor: ReactEditor) => {

    const Code = ContentModel.create<ContentModel.Code>(
      { type: 'code', language: 'python',
        startingLineNumber: 1, children: [
          { type: 'code_line', children: [{ text: '' }] }], id: guid() });
    Transforms.insertNodes(editor, Code);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-laptop-code',
  description: 'Code',
  command,
};

export interface CodeProps extends EditorProps<ContentModel.Code> {
}

export const CodeEditor = (props: CodeProps) => {

  const { editor } = props;
  const { model } = props;

  function onChange(e: any) {
    const language = e.target.value;
    updateModel(editor, model, { language });
  }

  const codeStyle = {
    fontFamily: 'Menlo, Monaco, Courier New, monospace',
    padding: '9px',
    marginLeft: '20px',
    marginRight: '20px',
    border: '1px solid #eeeeee',
    borderLeft: '2px solid darkblue',
    minHeight: '60px',
    position: 'relative',
    backgroundColor: '#DDDDDD',
  } as any;

  const label = {
    textTransform: 'uppercase',
    color: 'black',
  } as any;

  return (
    <div {...props.attributes} style={ codeStyle }>
      <pre >
        <code>{props.children}</code>
      </pre>
      <div
        contentEditable={false}
        style={{ position: 'absolute', top: '5px', right: '30px' }}
      >
        <span style={ label }>Code Block</span>
      </div>
      <div
        contentEditable={false}
        style={{ position: 'absolute', bottom: '5px', right: '25px' }}
      >
        <select value={model.language} onChange={onChange}>
          <option value="python">Python</option>
          <option value="css">CSS</option>
          <option value="js">JavaScript</option>
          <option value="html">HTML</option>
        </select>
      </div>
    </div>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
