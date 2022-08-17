import React, { useCallback } from 'react';
import { ReactEditor } from 'slate-react';
import { Transforms, Editor, Path, Element } from 'slate';
import {
  Table,
  TableBorderStyle,
  TableCell,
  TableData,
  TableHeader,
  TableRow,
  TableRowStyle,
} from 'data/content/model/elements/types';
import { Model } from 'data/content/model/elements/factories';
import {
  canExpandCellRight,
  canExpandDown,
  canSplitCell,
  expandCellDown,
  expandCellRight,
  splitCell,
} from './table-cell-merge-operations';

// Dropdown menu that appears in each table cell.
interface Props {
  editor: Editor;
  model: TableCell;
}

export const DropdownMenu: React.FC<Props> = ({ editor, model }) => {
  const ref = useCallback((reference: HTMLButtonElement) => {
    if (reference) {
      // TODO - probably be nice to get rid of the jquery dependency for a dropdown.
      (window.$(reference) as any).dropdown();
    }
  }, []);

  const onToggleHeader = () => {
    const path = ReactEditor.findPath(editor, model);

    const type = model.type === 'th' ? 'td' : 'th';
    Transforms.setNodes(editor, { type }, { at: path });
  };

  const onAddRowBefore = () => {
    const path = ReactEditor.findPath(editor, model);
    const [parent, parentPath] = Editor.parent(editor, path);

    const count = parent.children.length;
    const tds = [];
    for (let i = 0; i < count; i += 1) {
      tds.push(Model.td(''));
    }
    const row: TableRow = Model.tr(tds);

    Transforms.insertNodes(editor, row, { at: parentPath });
  };

  const onAddRowAfter = () => {
    const path = ReactEditor.findPath(editor, model);
    const [parent, parentPath] = Editor.parent(editor, path);

    const count = parent.children.length;
    const tds = [];
    for (let i = 0; i < count; i += 1) {
      tds.push(Model.td(''));
    }
    const row: TableRow = Model.tr(tds);
    Transforms.insertNodes(editor, row, { at: Path.next(parentPath) });
  };

  const onAddColumnBefore = () => {
    Editor.withoutNormalizing(editor, () => {
      const path = ReactEditor.findPath(editor, model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.insertNodes(editor, Model.td(''), { at: path });
      }
    });
  };

  const onAddColumnAfter = () => {
    Editor.withoutNormalizing(editor, () => {
      const path = ReactEditor.findPath(editor, model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.insertNodes(editor, Model.td(''), { at: Path.next(path) });
      }
    });
  };

  const onDeleteRow = () => {
    const path = ReactEditor.findPath(editor, model);
    Transforms.deselect(editor);
    Transforms.removeNodes(editor, { at: Path.parent(path) });
  };

  const onDeleteColumn = () => {
    Editor.withoutNormalizing(editor, () => {
      const path = ReactEditor.findPath(editor, model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);

      const rows = table.children.length;
      for (let i = 0; i < rows; i += 1) {
        path[path.length - 2] = i;
        Transforms.removeNodes(editor, { at: path });
      }
    });
  };

  const onDeleteTable = () => {
    const [tableEntry] = Editor.nodes(editor, {
      match: (n) => Element.isElement(n) && n.type === 'table',
    });
    if (!tableEntry) return;
    const [, path] = tableEntry;
    Transforms.removeNodes(editor, { at: path });
  };

  const onBorderStyle = useCallback(
    (style: TableBorderStyle) => (_event: any) => {
      const [tableEntry] = Editor.nodes(editor, {
        match: (n) => Element.isElement(n) && n.type === 'table',
      });
      if (!tableEntry) return;

      const [, path] = tableEntry;
      Transforms.setNodes<Table>(editor, { border: style }, { at: path });
    },
    [editor],
  );

  const onRowStyle = useCallback(
    (style: TableRowStyle) => (_event: any) => {
      const [tableEntry] = Editor.nodes(editor, {
        match: (n) => Element.isElement(n) && n.type === 'table',
      });
      if (!tableEntry) return;

      const [, path] = tableEntry;
      Transforms.setNodes<Table>(editor, { rowstyle: style }, { at: path });
    },
    [editor],
  );

  const toggleAlignment = useCallback(
    (alignment: string) => (_event: any) => {
      const [cellEntry] = Editor.nodes(editor, {
        match: (n) => Element.isElement(n) && (n.type === 'td' || n.type === 'th'),
      });
      if (!cellEntry) return;

      const [, path] = cellEntry;
      Transforms.setNodes<TableData | TableHeader>(editor, { align: alignment }, { at: path });
    },
    [editor],
  );

  const canMergeDown = canExpandDown(editor);
  const canMergeRight = canExpandCellRight(editor);
  const canSplit = canSplitCell(editor);

  return (
    <div className="dropdown table-dropdown" contentEditable={false}>
      <button
        ref={ref}
        type="button"
        className="dropdown-toggle btn"
        data-reference="parent"
        data-toggle="dropdown"
        aria-haspopup="true"
        aria-expanded="false"
      >
        <span className="sr-only">Toggle Table Cell Options</span>
      </button>
      <div className="dropdown-menu">
        <button type="button" className="dropdown-item" onClick={onToggleHeader}>
          Toggle Header
        </button>
        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Border</h6>

        <button type="button" className="dropdown-item" onClick={onBorderStyle('solid')}>
          Solid
        </button>

        <button type="button" className="dropdown-item" onClick={onBorderStyle('hidden')}>
          Hidden
        </button>

        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Row Style</h6>

        <button type="button" className="dropdown-item" onClick={onRowStyle('plain')}>
          Plain
        </button>

        <button type="button" className="dropdown-item" onClick={onRowStyle('alternating')}>
          Alternating Stripes
        </button>

        <div className="dropdown-divider"></div>
        <h6 className="dropdown-header">Split / Merge</h6>
        <button
          disabled={!canMergeRight}
          type="button"
          className="dropdown-item"
          onClick={() => expandCellRight(editor)}
        >
          Merge Right
        </button>
        <button
          disabled={!canMergeDown}
          type="button"
          className="dropdown-item"
          onClick={() => expandCellDown(editor)}
        >
          Merge Down
        </button>

        <button
          disabled={!canSplit}
          type="button"
          className="dropdown-item"
          onClick={() => splitCell(editor)}
        >
          Split Cell
        </button>

        <div className="dropdown-divider"></div>
        <h6 className="dropdown-header">Alignment</h6>

        <div className="ml-3 btn-group btn-group-toggle">
          <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('left')}>
            <i className="material-icons-outlined">format_align_left</i>
          </button>
          <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('center')}>
            <i className="material-icons-outlined">format_align_center</i>
          </button>
          <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('right')}>
            <i className="material-icons-outlined">format_align_right</i>
          </button>
        </div>

        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Insert</h6>
        <button type="button" className="dropdown-item" onClick={onAddRowBefore}>
          Row before
        </button>
        <button type="button" className="dropdown-item" onClick={onAddRowAfter}>
          Row after
        </button>
        <button type="button" className="dropdown-item" onClick={onAddColumnBefore}>
          Column before
        </button>
        <button type="button" className="dropdown-item" onClick={onAddColumnAfter}>
          Column after
        </button>

        <div className="dropdown-divider"></div>

        <h6 className="dropdown-header">Delete</h6>
        <button type="button" className="dropdown-item" onClick={onDeleteRow}>
          Row
        </button>
        <button type="button" className="dropdown-item" onClick={onDeleteColumn}>
          Column
        </button>

        <button type="button" className="dropdown-item" onClick={onDeleteTable}>
          Table
        </button>
      </div>
    </div>
  );
};
