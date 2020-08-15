import React, { useState, useRef, useEffect } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor as SlateEditor, Node, Text, Operation, Editor, Path } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps, CommandContext } from './interfaces';
import guid from 'utils/guid';
import * as Settings from './Settings';
import { toggleMark } from '../commands';
import { getNearestBlock } from '../utils';

const parentTextTypes = {
  p: true,
  code_line: true,
};

const isActiveCodeBlock = (editor: ReactEditor) => {
  /*
getNearestBlock(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type as string]) {
        const path = ReactEditor.findPath(editor, n);
        Transforms.setNodes(editor, { type: nextType }, { at: path });
      }
    });
  */

  return getNearestBlock(editor)
    .caseOf({
      just: n => n.type === 'code_line' || n.type === 'code',
      nothing: () => false,
    });
};

const selectedType = (editor: ReactEditor) => getNearestBlock(editor).caseOf({
  just: n => (parentTextTypes as any)[n.type as string] ? n.type as string : 'p',
  nothing: () => 'p',
});

const languages = Object
  .keys(ContentModel.CodeLanguages)
  .filter(k => typeof ContentModel.CodeLanguages[k as any] === 'number')
  .sort();

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    // Returns a NodeEntry with the selected code Node if it exists
    const codeEntries = Array.from(SlateEditor.nodes(editor, {
      match: n => n.code === true,
    }));

    // Helpers
    const isActiveInlineCode = () => {
      return !!codeEntries[0];
    };

    // update children to the nodes that's inside the selection
    const addCodeBlock = () => {
      const Code = ContentModel.create<ContentModel.Code>(
        {
          type: 'code',
          language: 'python',
          showNumbers: false,
          startingLineNumber: 1,
          children: [
            // The NodeEntry has the actual code Node at its first index
            { type: 'code_line', children: codeEntries.map(([child]) => child) }], id: guid(),
        });
      // insert newline and add code there instead of wrapping the nodes in line
      Transforms.insertNodes(editor, Code);
    };

    function removeCodeBlock() {
      getNearestBlock(editor).lift((node) => {

        console.log('node', node)



        // The code block is the root if multiple code lines are selected,
        // otherwise it's the parent of the code line
        const [codeBlock, codeBlockPath] = node.type === 'code'
          ? [node, ReactEditor.findPath(editor, node)]
          : SlateEditor.parent(editor, ReactEditor.findPath(editor, node));

        console.log('codeBlock', codeBlock)


        //  Transforms.unsetNode to remove code marks does not work here because
        // of model constraints, so we manually delete the code property.
        const paragraphs = (codeBlock.children as Node[]).map(codeLine =>
          ContentModel.create<ContentModel.Paragraph>(
            {
              type: 'p', children: (codeLine.children as Node[])
                .map((child) => {
                  const node = Object.assign({}, child);
                  if (node.code) {
                    delete node.code;
                  }
                  return node;
                }) as Node[], id: guid(),
            }));
        const paths = [];
        let nextPath = Path.next(codeBlockPath);
        paragraphs.forEach(p => {
          Transforms.insertNodes(editor, p, { at: nextPath });
          nextPath = Path.next(nextPath);
          paths.push(nextPath)
        });
        Transforms.select(editor, )



        console.log('code block path', codeBlockPath)
        // Transforms.insertFragment(editor, paragraphs, { at: Path.next(codeBlockPath) });
        Transforms.removeNodes(editor, { at: codeBlockPath });
        // Transforms.select(editor, Path.next(codeBlockPath));







        // console.log('codelines', codeLines)

        // console.log('path', codeBlockPath)
      })
      // Transforms.unsetNodes(editor, 'code', {
      //   at: Path.next(codeBlockPath),
      //   match: node => Text.isText(node),
      //   mode: 'lowest',
      // });
      // Transforms.removeNodes(editor, { at: codeBlockPath });
      // // Transforms.setNodes(editor, { type: 'p' },
      // //   { at: codeBlockPath, match: node => node.type === 'code_line' });
      // Transforms.insertNodes(editor,
      //   codeLines.map(line => Object.assign({}, line, { type: 'p' })), { at: codeBlockPath });


      // Transforms.liftNodes(editor, { at: codeBlockPath,})
      // Transforms.unwrapNodes(editor, { at: codeBlockPath, match:
      // node => node.type === 'code', mode: 'highest' });
      // Transforms.setNodes(editor, { type: 'p' },
      // { at: codeBlockPath, match: node => node.type === 'code_line' });
    }

    // Logic
    if (isActiveCodeBlock(editor)) {
      removeCodeBlock();
    }
    if (!isActiveInlineCode()) {
      return toggleMark(editor, 'code');
    }
    if (!isActiveCodeBlock(editor)) {
      return addCodeBlock();
    }
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

const description = (editor: ReactEditor) => {
  if (isActiveCodeBlock(editor)) {
    return 'Code-line';
  }
  return 'Code';
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'code',
  description,
  command,
  active: marks => marks.indexOf('code') !== -1,
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
              onClick={() => props.onRemove()} />
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
            onKeyPress={e => Settings.onEnterApply(e, () => props.onEdit(model))}
            className="form-control mr-sm-2" />

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
    onEdit={onEdit} />;

  return (
    <div {...props.attributes} className="code-editor">
      <div className="code-editor-content">
        <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }} >
          <code className={`language-${model.language}`}>{props.children}</code>
        </pre>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen}
          label="Code" />
        <Settings.Caption caption={model.caption} />
      </div>
    </div>
  );
};

export const CodeBlockLine = (props: any) => {
  return <div {...props.attributes}>{props.children}</div>;
};
