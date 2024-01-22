import React, { useCallback } from 'react';
import { Dropdown } from 'react-bootstrap';
import { Editor, Element, Path, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { Model } from 'data/content/model/elements/factories';
import {
  Table,
  TableBorderStyle,
  TableCell,
  TableData,
  TableHeader,
  TableRow,
  TableRowStyle,
} from 'data/content/model/elements/types';
import {
  canExpandCellRight,
  canExpandDown,
  canSplitCell,
  expandCellDown,
  expandCellRight,
  splitCell,
} from './table-cell-merge-operations';
import { getColspan, getRowColumnIndex, getRowspan, getVisualGrid } from './table-util';

// Dropdown menu that appears in each table cell.
interface Props {
  editor: Editor;
  model: TableCell;
  mode?: 'table' | 'conjugation'; // The conjugation element has a special kind of table that uses most, but not all, of this functionality
}

const Columns = ({ children }: { children: React.ReactNode }) => (
  <div className="d-flex flex-row">{children}</div>
);

const LeftColumn = ({ children }: { children: React.ReactNode }) => (
  <div className="d-flex flex-column border-r-2">{children}</div>
);

const RightColumn = ({ children }: { children: React.ReactNode }) => (
  <div className="d-flex flex-column">{children}</div>
);

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

  const undefinedOrOne = (value: number | undefined) => value === undefined || value === 1;

  const onDeleteRow = () => {
    Editor.withoutNormalizing(editor, () => {
      const path = ReactEditor.findPath(editor, model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);
      // When we delete a row, we have to delete the row, and any cells that have a rowspan > 1 in that row should
      // have their rowspan reduced by 1.
      Transforms.deselect(editor);
      Transforms.removeNodes(editor, { at: Path.parent(path) });

      const visualGrid = getVisualGrid(table as Table);
      const targetCellId = model.id;
      const coords = getRowColumnIndex(visualGrid, targetCellId);
      if (!coords) return; // This should never happen, but just in case
      const { rowIndex } = coords;
      const visualRow = visualGrid[rowIndex];
      const alreadyModified: TableCell[] = [];

      // Go through each cell in the row and reduce the rowspan of any cells that have a rowspan > 1.
      for (let columnIndex = 0; columnIndex < visualRow.length; columnIndex++) {
        const cell = visualRow[columnIndex];
        const cellPath = ReactEditor.findPath(editor, cell);

        if (alreadyModified.includes(cell)) continue; // A cell with a bigger rowspan only needs to be deleted/shrunk once
        alreadyModified.push(cell);

        if (getRowspan(cell) > 1) {
          Transforms.setNodes(editor, { rowspan: getRowspan(cell) - 1 }, { at: cellPath });
          // Shrinking cell's rowspan
        }
      }
    });
  };

  const onDeleteColumn = () => {
    Editor.withoutNormalizing(editor, () => {
      const path = ReactEditor.findPath(editor, model);
      const [, parentPath] = Editor.parent(editor, path);
      const [table] = Editor.parent(editor, parentPath);
      const visualGrid = getVisualGrid(table as Table);
      const targetCellId = model.id;

      // Figure out what visual column we want to delete.
      const coords = getRowColumnIndex(visualGrid, targetCellId);
      if (!coords) return; // This should never happen, but just in case
      const { columnIndex } = coords;

      const alreadyModified: TableCell[] = [];

      // Go through each row and delete the cell at the target column index.
      // If the cell is a merged cell, we need to just remove one from it's colspan
      // and not delete the cell.
      for (let rowIndex = 0; rowIndex < visualGrid.length; rowIndex++) {
        const row = visualGrid[rowIndex];
        const cell = row[columnIndex];
        const cellPath = ReactEditor.findPath(editor, cell);

        if (alreadyModified.includes(cell)) continue; // A cell with a bigger rowspan only needs to be deleted/shrunk once
        alreadyModified.push(cell);

        if (getColspan(cell) > 1) {
          Transforms.setNodes(editor, { colspan: getColspan(cell) - 1 }, { at: cellPath });
          // Shrinking cell's colspan
        } else {
          Transforms.removeNodes(editor, { at: cellPath });
          // Deleting cell
        }
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
        <Columns>
          <LeftColumn>
            {mode == 'table' && <AlignmentOptions editor={editor} />}

            <Dropdown.Header>Header</Dropdown.Header>
            <Dropdown.Item onClick={onToggleHeader}>Toggle Header</Dropdown.Item>
            <Dropdown.Divider />

            <Dropdown.Header>Border</Dropdown.Header>

            <Dropdown.Item onClick={onBorderStyle('solid')}>Solid</Dropdown.Item>

            <Dropdown.Item onClick={onBorderStyle('hidden')}>Hidden</Dropdown.Item>

            {mode == 'table' && <AddOptions editor={editor} model={model} />}
          </LeftColumn>
          <RightColumn>
            <Dropdown.Header>Row Style</Dropdown.Header>

            <Dropdown.Item onClick={onRowStyle('plain')}>Plain</Dropdown.Item>

            <Dropdown.Item onClick={onRowStyle('alternating')}>Alternating Stripes</Dropdown.Item>

            <Dropdown.Divider />

            {mode == 'table' && <SplitOptions editor={editor} />}

            <Dropdown.Divider />

            <Dropdown.Header>Delete</Dropdown.Header>
            {undefinedOrOne(model.rowspan) && (
              <Dropdown.Item onClick={onDeleteRow}>Row</Dropdown.Item>
            )}
            {undefinedOrOne(model.colspan) && (
              /* Do not allow us to delete rows or columns if starting from a merged cell */
              <Dropdown.Item onClick={onDeleteColumn}>Column</Dropdown.Item>
            )}

            <Dropdown.Item onClick={onDeleteTable}>Table</Dropdown.Item>
          </RightColumn>
        </Columns>
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

      <Dropdown.Divider />
    </>
  );
};

const SplitOptions: React.FC<{ editor: Editor }> = ({ editor }) => {
  const canMergeDown = canExpandDown(editor);
  const canMergeRight = canExpandCellRight(editor);
  const canSplit = canSplitCell(editor);

  return (
    <>
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
