import React, { useEffect, useRef } from 'react';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';
import { Transforms, Editor, Path } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { LabelledTextEditor } from 'components/TextEditor';
import { SizePicker } from './SizePicker';
import Popover from 'react-tiny-popover';

// Helper functions for creating tables and its parts
const td = (text: string) => ContentModel.create<ContentModel.TableData>(
  { type: 'td', children: [{ type: 'p', children: [{ text }] }], id: guid() });

const tr = (children: ContentModel.TableData[]) => ContentModel.create<ContentModel.TableRow>(
  { type: 'tr', children, id: guid() });

const table = (children: ContentModel.TableRow[]) => ContentModel.create<ContentModel.Table>(
  { type: 'table', children, id: guid() });


// The UI command for creating tables
const command: Command = {
  execute: (context: any, editor: ReactEditor, params: any) => {

    const rows: any = [];

    for (let i = 0; i < params.rows; i += 1) {
      const tds = [];
      for (let j = 0; j < params.columns; j += 1) {
        tds.push(td(''));
      }
      rows.push(tr(tds));
    }

    const t = table(rows);
    Transforms.insertNodes(editor, t);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },

  obtainParameters: (editor: ReactEditor,
    onDone: (params: any) => void, onCancel: () => void) => {

    return <SizePicker onHide={onCancel}
      onTableCreate={(rows, columns) => onDone({ rows, columns })} />;
  },
};

// Dropdown menu that appears in each table cell.
const DropdownMenu = (props: any) => {

  const ref = useRef();

  // There has to be a better way to do this.
  useEffect(() => {
    if (ref !== null && ref.current !== null) {
      ((window as any).$('.dropdown-toggle') as any).dropdown();
    }
  });

  const onToggleHeader = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);

    const type = props.model.type === 'th' ? 'td' : 'th';
    Transforms.setNodes(editor, { type }, { at: path });
  };

  const onAddRowBefore = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [parent, parentPath] = Editor.parent(editor, path);

    const count = parent.children.length;
    const tds = [];
    for (let i = 0; i < count; i += 1) {
      tds.push(td(''));
    }
    const row: ContentModel.TableRow = tr(tds);

    Transforms.insertNodes(editor, row, { at: parentPath });
  };

  const onAddRowAfter = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [parent, parentPath] = Editor.parent(editor, path);

    const count = parent.children.length;
    const tds = [];
    for (let i = 0; i < count; i += 1) {
      tds.push(td(''));
    }
    const row: ContentModel.TableRow = tr(tds);
    Transforms.insertNodes(editor, row, { at: Path.next(parentPath) });

  };

  const onAddColumnBefore = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [, parentPath] = Editor.parent(editor, path);
    const [table] = Editor.parent(editor, parentPath);

    const rows = table.children.length;
    for (let i = 0; i < rows; i += 1) {
      path[path.length - 2] = i;
      Transforms.insertNodes(editor, td(''), { at: path });
    }
  };

  const onAddColumnAfter = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [, parentPath] = Editor.parent(editor, path);
    const [table] = Editor.parent(editor, parentPath);

    const rows = table.children.length;
    for (let i = 0; i < rows; i += 1) {
      path[path.length - 2] = i;
      Transforms.insertNodes(editor, td(''), { at: Path.next(path) });
    }
  };

  const onDeleteRow = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    Transforms.deselect(editor);
    Transforms.removeNodes(editor, { at: Path.parent(path) });
  };

  const onDeleteColumn = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [, parentPath] = Editor.parent(editor, path);
    const [table] = Editor.parent(editor, parentPath);

    const rows = table.children.length;
    for (let i = 0; i < rows; i += 1) {
      path[path.length - 2] = i;
      Transforms.removeNodes(editor, { at: path });
    }
  };

  const style = {
    float: 'right',
  } as any;

  const buttonStyle = {
    border: 'none',
    outline: 'none',

  };

  return (
    <div ref={ref as any} className="dropdown table-dropdown" style={style} contentEditable={false}>
      <button type="button"
        style={buttonStyle}
        className="dropdown-toggle btn"
        data-reference="parent"
        data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
        <span className="sr-only">Toggle Dropdown</span>
      </button>
      <div className="dropdown-menu">
        <h6 className="dropdown-header">Insert</h6>
        <div className="dropdown-item" onClick={onAddRowBefore}>Row before</div>
        <div className="dropdown-item" onClick={onAddRowAfter}>Row after</div>
        <div className="dropdown-item" onClick={onAddColumnBefore}>Column before</div>
        <div className="dropdown-item" onClick={onAddColumnAfter}>Column after</div>

        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Delete</h6>
        <div className="dropdown-item" onClick={onDeleteRow}>Row</div>
        <div className="dropdown-item" onClick={onDeleteColumn}>Column</div>

        <div className="dropdown-divider"></div>
        <div className="dropdown-item" onClick={onToggleHeader}>Toggle Header</div>
      </div>
    </div>
  );
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-table',
  description: 'Table',
  command,
};

export interface TableProps extends EditorProps<ContentModel.Table> {
}

export const TdEditor = (props: EditorProps<ContentModel.TableData>) => {

  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const maybeMenu = selected && focused
    ? <DropdownMenu editor={editor} model={props.model} /> : null;

  return (
    <td {...props.attributes}>
      {maybeMenu}
      {props.children}
    </td>
  );
};

export const ThEditor = (props: EditorProps<ContentModel.TableHeader>) => {

  const editor = useSlate();
  const selected = useSelected();
  const focused = useFocused();

  const maybeMenu = selected && focused
    ? <DropdownMenu editor={editor} model={props.model} /> : null;

  return (
    <th {...props.attributes}>
      {maybeMenu}
      {props.children}
    </th>
  );
};

export const TrEditor = (props: EditorProps<ContentModel.TableRow>) => {
  return (
    <tr {...props.attributes}>{props.children}</tr>
  );
};

export const TableEditor = (props: TableProps) => {

  const selected = useSelected();
  const focused = useFocused();

  const { attributes, children, editor } = props;
  const { model } = props;

  const editMode = getEditMode(editor);

  const onEditCaption = (caption: string) => updateModel(editor, model, { caption });

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div style={{ margin: '20px' }}>

      <div>
        <table className="table table-bordered">
          <tbody {...attributes} >
            {children}
          </tbody>
        </table>
      </div>

      <div contentEditable={false} style={{ userSelect: 'none' }}>
        <div style={{ marginLeft: '30px' }}>
          <LabelledTextEditor
            label="Caption"
            model={model.caption || ''}
            onEdit={onEditCaption}
            showAffordances={selected && focused}
            editMode={editMode} />
        </div>
      </div>
    </div>
  );
};
