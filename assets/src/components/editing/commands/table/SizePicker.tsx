import { useState } from 'react';

type Size = {
  rows: number;
  columns: number;
};

const initialSize: Size = { rows: 1, columns: 1 };

const minRows = 4;
const minCols = 4;
const maxRows = 15;
const maxCols = 15;

const cellContainerStyle = {
  padding: '2px',
  display: 'inline-block',
  cursor: 'pointer',
  lineHeight: '0',
};

const DEFAULT_BORDER_COLOR = '#ededed';
const HIGHLIGHTED_BORDER_COLOR = '#ccdefb';
const DEFAULT_BACKGROUND_COLOR = '#f8f8f8';
const HIGHLIGHTED_BACKGROUND_COLOR = '#e0eafb';

const cellStyle = (isHighlighted: boolean) => ({
  backgroundColor: isHighlighted ? HIGHLIGHTED_BACKGROUND_COLOR : DEFAULT_BACKGROUND_COLOR,
  border: `1px solid ${isHighlighted ? HIGHLIGHTED_BORDER_COLOR : DEFAULT_BORDER_COLOR}`,
  borderRadius: '2px',
  padding: '0px',
  margin: '0px',
  display: 'inline-block',
  height: '15px',
  width: '15px',
});

const range = (n: number) =>
  Array.apply(null, { length: n })
    .map(Number.call, Number)
    .map((v: any) => v + 1);

export type SizePickerProps = {
  onTableCreate: (rows: number, columns: number) => void;
};

export const SizePicker = (props: SizePickerProps) => {
  const [size, setSize] = useState(initialSize);

  const isHighlighted = (row: number, col: number) => size.rows >= row && size.columns >= col;

  const numRows = Math.min(Math.max(size.rows, minRows) + 1, maxRows);
  const numCols = Math.min(Math.max(size.columns, minCols) + 1, maxCols);

  const rows = range(numRows);
  const cols = range(numCols);

  const width = numCols * 19 + 15 + 'px';
  const height = numRows * 25 + 35 + 'px';

  const mapRow = (row: number) => {
    const cells = cols.map((col: number) => (
      <div
        key={'col' + col}
        style={cellContainerStyle}
        onMouseEnter={(e) => setSize({ rows: row, columns: col })}
        onMouseDown={(e) => {
          setSize({ rows: 1, columns: 1 });
          props.onTableCreate(row, col);
        }}
      >
        <div style={cellStyle(isHighlighted(row, col))} />
      </div>
    ));

    return <div key={'row' + row}>{cells}</div>;
  };

  const gridStyle = {
    height,
    width,
    padding: '5px',
    backgroundColor: 'white',
    borderRadius: '4px',
    border: '1px solid #eee',
  } as any;

  const labelStyle = {
    width,
    color: '#808080',
    textAlign: 'center',
  } as any;

  const sizeLabel = size.rows + ' by ' + size.columns;

  return (
    <div style={gridStyle}>
      {rows.map(mapRow)}
      <div style={labelStyle}>{sizeLabel}</div>
    </div>
  );
};
