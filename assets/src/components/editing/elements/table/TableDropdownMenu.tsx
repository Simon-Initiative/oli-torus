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
import { Dropdown } from 'react-bootstrap';

// Dropdown menu that appears in each table cell.
interface Props {
  editor: Editor;
  model: TableCell;
  mode?: 'table' | 'conjugation'; // The conjugation element has a special kind of table that uses most, but not all, of this functionality
}

export const DropdownMenu: React.FC<Props> = ({ editor, model, mode = 'table' }) => {
  const onToggleHeader = () => {
    const path = ReactEditor.findPath(editor, model);
    const cellType = mode == 'conjugation' ? 'tc' : 'td';
    const type = model.type === 'th' ? cellType : 'th';
    Transforms.setNodes(editor, { type }, { at: path });
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

  return (
    <Dropdown className="table-dropdown" contentEditable={false}>
      <Dropdown.Toggle className="dropdown-toggle btn">
        <span className="sr-only">Toggle Table Cell Options</span>
        <i className="fa-solid fa-ellipsis-vertical"></i>
      </Dropdown.Toggle>
      <Dropdown.Menu>
        <Dropdown.Item onClick={onToggleHeader}>Toggle Header</Dropdown.Item>
        <Dropdown.Divider />

        <Dropdown.Header>Border</Dropdown.Header>

        <Dropdown.Item onClick={onBorderStyle('solid')}>Solid</Dropdown.Item>

        <Dropdown.Item onClick={onBorderStyle('hidden')}>Hidden</Dropdown.Item>

        <Dropdown.Divider />

        <Dropdown.Header>Row Style</Dropdown.Header>

        <Dropdown.Item onClick={onRowStyle('plain')}>Plain</Dropdown.Item>

        <Dropdown.Item onClick={onRowStyle('alternating')}>Alternating Stripes</Dropdown.Item>

        {mode == 'table' && <SplitOptions editor={editor} />}
        {mode == 'table' && <AlignmentOptions editor={editor} />}
        {mode == 'table' && <AddOptions editor={editor} model={model} />}

        <Dropdown.Divider />

        <Dropdown.Header>Delete</Dropdown.Header>
        <Dropdown.Item onClick={onDeleteRow}>Row</Dropdown.Item>
        <Dropdown.Item onClick={onDeleteColumn}>Column</Dropdown.Item>

        <Dropdown.Item onClick={onDeleteTable}>Table</Dropdown.Item>
      </Dropdown.Menu>
    </Dropdown>
  );
};

const AddOptions: React.FC<{ editor: Editor; model: TableCell }> = ({ editor, model }) => {
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

  return (
    <>
      <Dropdown.Divider />

      <Dropdown.Header>Insert</Dropdown.Header>
      <Dropdown.Item onClick={onAddRowBefore}>Row before</Dropdown.Item>
      <Dropdown.Item onClick={onAddRowAfter}>Row after</Dropdown.Item>
      <Dropdown.Item onClick={onAddColumnBefore}>Column before</Dropdown.Item>
      <Dropdown.Item onClick={onAddColumnAfter}>Column after</Dropdown.Item>
    </>
  );
};

const AlignmentOptions: React.FC<{ editor: Editor }> = ({ editor }) => {
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
  return (
    <>
      <Dropdown.Divider />

      <Dropdown.Header>Alignment</Dropdown.Header>

      <div className="ml-3 btn-group btn-group-toggle">
        <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('left')}>
          <i className="fa-solid fa-align-left"></i>
        </button>
        <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('center')}>
          <i className="fa-solid fa-align-center"></i>
        </button>
        <button className="btn btn-sm btn-secondary" onClick={toggleAlignment('right')}>
          <i className="fa-solid fa-align-right"></i>
        </button>
      </div>
    </>
  );
};

const SplitOptions: React.FC<{ editor: Editor }> = ({ editor }) => {
  const canMergeDown = canExpandDown(editor);
  const canMergeRight = canExpandCellRight(editor);
  const canSplit = canSplitCell(editor);

  return (
    <>
      <Dropdown.Divider />

      <Dropdown.Header>Split / Merge</Dropdown.Header>

      <Dropdown.Item disabled={!canMergeRight} onClick={() => expandCellRight(editor)}>
        Merge Right
      </Dropdown.Item>
      <Dropdown.Item disabled={!canMergeDown} onClick={() => expandCellDown(editor)}>
        Merge Down
      </Dropdown.Item>

      <Dropdown.Item disabled={!canSplit} onClick={() => splitCell(editor)}>
        Split Cell
      </Dropdown.Item>
    </>
  );
};
