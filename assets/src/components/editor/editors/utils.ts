import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';

/**
 * Updates a model element that is contained in a slate data model hierarchy.
 * @param editor the slate instance containing the model
 * @param model the current state of the model
 * @param changes a partial object containing the changes that are to be applied to the model
 */
export function updateModel<T extends ContentModel.ModelElement>(
  editor: ReactEditor, model: T, changes: Partial<T>) {
  const path = ReactEditor.findPath(editor, model);
  Transforms.setNodes(editor, changes, { at: path });
}

/**
 * Determines the edit mode of a slate instance. Returns true if
 * the slate editor is allowing edits, false otherwise.
 * @param editor the slate instance
 */
export function getEditMode(editor: ReactEditor) {
  return !ReactEditor.isReadOnly(editor);
}
