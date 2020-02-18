import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';

export function updateModel<T extends ContentModel.ModelElement>(editor: ReactEditor, model: T, changes: Partial<T>) {
  const path = ReactEditor.findPath(editor, model);
  Transforms.setNodes(editor, changes, { at: path })
}

export function getEditMode(editor: ReactEditor) {
  return !ReactEditor.isReadOnly(editor);
}