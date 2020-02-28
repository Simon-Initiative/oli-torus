import React from 'react';
import { ReactEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from './utils';
import * as ContentModel from 'data/content/model';
import { Command, CommandDesc } from '../interfaces';
import { EditorProps } from './interfaces';
import guid from 'utils/guid';
import { LabelledTextEditor } from 'components/TextEditor';


const td = (text: string) => ContentModel.create<ContentModel.TableData>(
  { type: 'td', children: [{ type: 'p', children: [{ text }] }], id: guid() });

const tr = (children: ContentModel.TableData[]) => ContentModel.create<ContentModel.TableRow>(
  { type: 'tr', children, id: guid() });

const table = (children: ContentModel.TableRow[]) => ContentModel.create<ContentModel.Table>(
  { type: 'table', children, id: guid() });

const command: Command = {
  execute: (editor: ReactEditor) => {

    const t = table([
      tr([td('one'), td('two'), td('three')]),
      tr([td('four'), td('five'), td('six')]),
    ]);
    Transforms.insertNodes(editor, t);
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fab fa-table',
  description: 'Table',
  command,
};

export interface TableProps extends EditorProps<ContentModel.Table> {
}

export const TdEditor = (props: EditorProps<ContentModel.TableData>) => {

  const selected = useSelected();
  const focused = useFocused();


  const style = {
    float: 'right',
    opacity: 0.5,
    visibility: (selected && focused) ? 'visible' : 'hidden',
  } as any;

  const menu = (
    <div contentEditable={false} className="dropdown" style={style}>
      <button type="button"
        className="btn btn-danger dropdown-toggle"
        data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
        <span className="sr-only">Toggle Dropdown</span>
      </button>
      <div className="dropdown-menu">
        <a className="dropdown-item" href="#">Action</a>
        <a className="dropdown-item" href="#">Another action</a>
        <a className="dropdown-item" href="#">Something else here</a>
        <div className="dropdown-divider"></div>
        <a className="dropdown-item" href="#">Separated link</a>
      </div>
    </div>
  );

  return (
    <td {...props.attributes}>
      {menu}
      {props.children}
    </td>
  );
};

export const ThEditor = (props: EditorProps<ContentModel.TableHeader>) => {
  return (
    <th {...props.attributes}>{props.children}</th>
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
    <div {...attributes} style={ { margin: '20px' } }>

      <div className="table-responsive">
        <table className="table table-bordered">
          <tbody>
            {children}
          </tbody>
        </table>
      </div>

      <div contentEditable={false}>
        <div style={{ textAlign: 'center' }}>
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
