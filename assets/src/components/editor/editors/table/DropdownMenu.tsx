import React, { useEffect, useRef } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor, Path } from 'slate';
import * as ContentModel from 'data/content/model';

// Dropdown menu that appears in each table cell.
export const DropdownMenu = (props: any) => {

  const ref = useRef();
  const { editor } = props.editor;

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

  const onAddColumnBefore = () => {

    Editor.withoutNormalizing(editor, () => {

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

    Editor.withoutNormalizing(editor, () => {

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

    Editor.withoutNormalizing(editor, () => {

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
