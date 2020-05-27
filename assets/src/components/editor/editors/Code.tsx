import React, { useState } from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';

import { LabelledTextEditor } from 'components/TextEditor';

const languages = Object
  .keys(ContentModel.CodeLanguages)
  .filter(k => typeof ContentModel.CodeLanguages[k as any] === 'number')
  .sort();

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const Code = ContentModel.create<ContentModel.Code>(
      {
        type: 'code', language: 'python',
        showNumbers: false,
        startingLineNumber: 1, children: [
          { type: 'code_line', children: [{ text: '' }] }], id: guid(),
      });
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

  const [checkId] = useState(guid());
  const isActive = useSelected() && useFocused();
  const editMode = getEditMode(editor);

  const onChange = (e: any) => {
    const language = e.target.value;
    updateModel(editor, model, { language });
  };

  const onNumbersChange = () => {
    updateModel(editor, model, { showNumbers: !model.showNumbers });
  };

  const onEditCaption = (caption: string) => updateModel(editor, model, { caption });

  const codeStyle = {
    padding: '9px',
    marginLeft: '10px',
    border: '1px solid #eeeeee',
    borderLeft: '2px solid darkblue',
    minHeight: '60px',
    backgroundColor: '#DDDDDD',
  } as any;

  const attrStyle = {
    userSelect: 'none',
  } as any;

  const attributes = (
    <div
      contentEditable={false}
      style={attrStyle}
    >
      <form className="form-inline">

        <select disabled={!isActive}
          className="form-control form-control-sm" value={model.language} onChange={onChange}>
          {languages.map(lang => <option key={lang} value={lang}>{lang}</option>)}
        </select>

        <div className="form-check">
          <input disabled={!isActive} onChange={onNumbersChange}
            checked={model.showNumbers} type="checkbox" className="form-check-input" id={checkId + ''} />
          <label className="form-check-label" htmlFor={checkId + ''}>Line numbers</label>
        </div>

      </form>
    </div>
  );

  return (
    <div {...props.attributes}>
      <div style={codeStyle}>
        <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }} >
          <code>{props.children}</code>
        </pre>
        {attributes}
      </div>

      <div contentEditable={false} style={{ marginLeft: '30px', userSelect: 'none' }}>
        <LabelledTextEditor
          label="Caption"
          model={model.caption || ''}
          onEdit={onEditCaption}
          showAffordances={isActive}
          editMode={editMode} />
      </div>
    </div>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
