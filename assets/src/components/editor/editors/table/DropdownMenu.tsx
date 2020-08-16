import React, { useEffect, useRef } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor, Path } from 'slate';
import * as ContentModel from 'data/content/model';

// Dropdown menu that appears in each table cell.
export const DropdownMenu = (props: any) => {

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
      tds.push(ContentModel.td(''));
    }
    const row: ContentModel.TableRow = ContentModel.tr(tds);

    Transforms.insertNodes(editor, row, { at: parentPath });
  };

  const onAddRowAfter = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    const [parent, parentPath] = Editor.parent(editor, path);

    const count = parent.children.length;
    const tds = [];
    for (let i = 0; i < count; i += 1) {
      tds.push(ContentModel.td(''));
    }
    const row: ContentModel.TableRow = ContentModel.tr(tds);
    Transforms.insertNodes(editor, row, { at: Path.next(parentPath) });

  };

  // Wraps a table editing function so that the execution of the edits
  // within it operate outside of slate normalization.  This is to allow
  // edit sequences that would put the document in intermediate states
  // that normalization would seek to adjust to execute without that
  // adjustment.

  const withoutNormalization = (fn: any) => {
    const editor: ReactEditor = props.editor;

    try {

      (editor as any).suspendNormalization = true;

      fn(editor);

    } catch (error) {
      // tslint:disable-next-line
      console.error(error);

    } finally {
      // Whether the operation succeeded or failed, we restore
      // normalization
      (editor as any).suspendNormalization = false;
    }
  };

  const onAddColumnBefore = () => {

    withoutNormalization((editor: ReactEditor) => {

      const path = ReactEditor.findPath(editor, props.model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.insertNodes(editor, ContentModel.td(''), { at: path });
      }
    });

  };

  const onAddColumnAfter = () => {

    withoutNormalization((editor: ReactEditor) => {

      const path = ReactEditor.findPath(editor, props.model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.insertNodes(editor, ContentModel.td(''), { at: Path.next(path) });
      }
    });

  };

  const onDeleteRow = () => {
    const editor: ReactEditor = props.editor;
    const path = ReactEditor.findPath(editor, props.model);
    Transforms.deselect(editor);
    Transforms.removeNodes(editor, { at: Path.parent(path) });
  };

  const onDeleteColumn = () => {

    withoutNormalization((editor: ReactEditor) => {

      const path = ReactEditor.findPath(editor, props.model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.removeNodes(editor, { at: path });
      }
    });

  };

  return (
    <div ref={ref as any} className="dropdown table-dropdown" contentEditable={false}>
      <button type="button"
        className="dropdown-toggle btn"
        data-reference="parent"
        data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
        <span className="sr-only">Toggle Table Cell Options</span>
      </button>
      <div className="dropdown-menu">
        <h6 className="dropdown-header">Insert</h6>
        <button type="button"
          className="dropdown-item"
          onClick={onAddRowBefore}>Row before</button>
        <button type="button"
          className="dropdown-item"
          onClick={onAddRowAfter}>Row after</button>
        <button type="button"
          className="dropdown-item"
          onClick={onAddColumnBefore}>Column before</button>
        <button type="button"
          className="dropdown-item"
          onClick={onAddColumnAfter}>Column after</button>

        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Delete</h6>
        <button type="button"
          className="dropdown-item"
          onClick={onDeleteRow}>Row</button>
        <button type="button"
          className="dropdown-item"
          onClick={onDeleteColumn}>Column</button>

        <div className="dropdown-divider"></div>
        <button type="button"
          className="dropdown-item"
          onClick={onToggleHeader}>Toggle Header</button>
      </div>
    </div>
  );
};
