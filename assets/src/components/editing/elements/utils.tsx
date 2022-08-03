import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor, Transforms } from 'slate';

/**
 * Updates a model element that is contained in a slate data model hierarchy.
 * @param editor the slate instance containing the model
 * @param model the current state of the model
 * @param changes a partial object containing the changes that are to be applied to the model
 */
export function updateModel<T extends ContentModel.ModelElement>(
  editor: Editor,
  model: T,
  changes: Partial<T>,
) {
  const path = ReactEditor.findPath(editor, model);
  Transforms.setNodes(editor, changes, { at: path });
}

export const useEditModelCallback = <T extends ContentModel.ModelElement>(model: T) => {
  const editor = useSlate();

  return React.useCallback((attrs: Partial<T>) => updateModel<T>(editor, model, attrs), [editor]);
};

/**
 * Determines the edit mode of a slate instance. Returns true if
 * the slate editor is allowing edits, false otherwise.
 * @param editor the slate instance
 */
export function getEditMode(editor: ReactEditor) {
  return !ReactEditor.isReadOnly(editor);
}

// Slate bug as of 0.72.0. Prevents selection at the edges
// of an inline element.
// https://bugs.chromium.org/p/chromium/issues/detail?id=1249405
export const InlineChromiumBugfix = () => (
  <span contentEditable={false} style={{ fontSize: 0 }}>
    ${String.fromCodePoint(160) /* Non-breaking space */}
  </span>
);

export function elementBorderStyle(active: boolean): React.CSSProperties {
  return {
    border: active ? '3px solid blue' : '3px solid transparent',
    borderRadius: 3,
  };
}
