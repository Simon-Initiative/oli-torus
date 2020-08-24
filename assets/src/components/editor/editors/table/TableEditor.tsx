import React, { useState } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel, getEditMode } from 'components/editor/editors/utils';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';
import * as Settings from 'components/editor/editors/settings/Settings';
import { TableSettings } from './TableSettings';

export interface TableProps extends EditorProps<ContentModel.Table> {
}

export const TableEditor = (props: TableProps) => {

  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const { attributes, children, editor } = props;

  const [model, setModel] = useState(props.model);
  const setCaption = (caption: string) => setModel(Object.assign({}, model, { caption }));

  const editMode = getEditMode(editor);

  const onEdit = (updated: ContentModel.Table) => {
    updateModel<ContentModel.Table>(editor, model, updated);

    setIsPopoverOpen(false);
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');

    const path = ReactEditor.findPath(editor, model);
    Transforms.removeNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  const contentFn = () => <TableSettings
    model={model}
    editMode={editMode}
    commandContext={props.commandContext}
    onRemove={onRemove}
    onEdit={onEdit}/>;

  // Note that it is important that any interactive portions of a void editor
  // must be enclosed inside of a "contentEditable=false" container. Otherwise,
  // slate does some weird things that non-deterministically interface with click
  // events.

  return (
    <div className="table-editor ml-4 mr-4">

      <div>
        <table className="table table-bordered">
          <tbody {...attributes} >
            {children}
          </tbody>
        </table>
      </div>
      <div contentEditable={false} style={{ userSelect: 'none' }}>
        {/* <Settings.ToolPopupButton
          contentFn={contentFn}
          setIsPopoverOpen={setIsPopoverOpen}
          isPopoverOpen={isPopoverOpen}
          label="Table" /> */}
        <Settings.Input
          value={model.caption}
          onChange={value => setCaption(value)}
          editor={editor}
          model={model}
          placeholder="Type caption for table"
        />
      </div>
    </div>
  );
};
