import React, { useState, useRef, useEffect } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps, CommandContext } from './interfaces';
import guid from 'utils/guid';
import * as Settings from './Settings';
import './Settings.scss';
import './Code.scss';

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

type CodeSettingsProps = {
  model: ContentModel.Code,
  onEdit: (model: ContentModel.Code) => void,
  onRemove: () => void,
  commandContext: CommandContext,
  editMode: boolean,
};

const CodeSettings = (props: CodeSettingsProps) => {

  // Which selection is active, URL or in course page
  const [model, setModel] = useState(props.model);
  const [checkId] = useState(guid());

  const ref = useRef();

  useEffect(() => {

    // Inits the tooltips, since this popover rendres in a react portal
    // this was necessary
    if (ref !== null && ref.current !== null) {
      ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    }
  });

  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));

  const onChange = (e: any) => {
    const language = e.target.value;
    setModel(Object.assign({}, model, { language }));
  };

  const onNumbersChange = () => {
    setModel(Object.assign({}, model, { showNumbers: !model.showNumbers }));
  };

  const applyButton = (disabled: boolean) => <button onClick={(e) => {
    e.stopPropagation();
    e.preventDefault();
    props.onEdit(model);
  }}
  disabled={disabled}
  className="btn btn-primary ml-1">Apply</button>;

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>

        <div className="d-flex justify-content-between mb-2">
          <div>
            Source Code
          </div>

          <div>
            <Settings.Action icon="fas fa-trash" tooltip="Remove Code Block" id="remove-button"
              onClick={() => props.onRemove()}/>
          </div>
        </div>

        <form className="form">

          <label>Source Language</label>
          <select
            className="form-control form-control-sm mb-2"
            value={model.language} onChange={onChange}>
            {languages.map(lang => <option key={lang} value={lang}>{lang}</option>)}
          </select>

          <div className="form-check mb-2">
            <input onChange={onNumbersChange}
              checked={model.showNumbers} type="checkbox" className="form-check-input" id={checkId + ''} />
            <label className="form-check-label" htmlFor={checkId + ''}>Show line numbers</label>
          </div>

          <label>Caption</label>
          <input type="text" value={model.caption} onChange={e => setCaption(e.target.value)}
            className="form-control mr-sm-2"/>

        </form>

        {applyButton(!props.editMode)}

      </div>
    </div>
  );
};

export const CodeEditor = (props: CodeProps) => {

  const { editor } = props;
  const { model } = props;
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const editMode = getEditMode(editor);

  const onEdit = (updated: ContentModel.Code) => {
    updateModel<ContentModel.Code>(editor, model, updated);
    setIsPopoverOpen(false);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  const contentFn = () => <CodeSettings
    model={model}
    editMode={editMode}
    commandContext={props.commandContext}
    onRemove={onRemove}
    onEdit={onEdit}/>;

  return (
    <div {...props.attributes} className="ml-4 mr-4">
      <div className="code-editor">
        <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }} >
          <code>{props.children}</code>
        </pre>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen} />
        <Settings.Caption caption={model.caption}/>
      </div>
    </div>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
