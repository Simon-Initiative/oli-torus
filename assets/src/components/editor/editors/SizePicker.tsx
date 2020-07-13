import { useState } from 'react';

type Size = {
  rows: number,
  columns: number,
};

const initialSize: Size = { rows: 1, columns: 1 };

const maxRows = 10;
const maxCols = 8;

const cellContainerStyle = {
  padding: '2px',
  display: 'inline-block',
  cursor: 'pointer',
};

const cellStyle = (isHighlighted: boolean) => ({
  backgroundColor: isHighlighted ? '#81abef' : '#DDDDDD',
  border: '1px solid #DDDDDD',
  borderRadius: '3px',
  padding: '0px',
  margin: '0px',
  display: 'inline-block',
  height: '15px',
  width: '15px',
});

const range = (n: number) =>
  Array.apply(null, { length: n }).map(Number.call, Number).map((v: any) => v + 1);

export type SizePickerProps = {
  onHide: () => void;
  onTableCreate: (rows: number, columns: number) => void;
};

export const SizePicker = (props: SizePickerProps) => {

  const [size, setSize] = useState(initialSize);

  const isHighlighted = (row: number, col: number) => size.rows >= row && size.columns >= col;

  const numRows = maxRows;
  const numCols = maxCols;

  const rows = range(numRows);
  const cols = range(numCols);

  const width = (maxCols * 19 + 10) + 'px';
  const height = (maxRows * 25 + 35) + 'px';

  const mapRow = (row: number) => {
    const cells = cols.map((col: number) => (
      <div
        key={'col' + col}
        style={cellContainerStyle}
        onMouseEnter={e => setSize({ rows: row, columns: col })}
        onMouseDown={
          (e) => {
            setSize({ rows: 1, columns: 1 });
            props.onTableCreate(row, col);
          }
        }>
        <div style={cellStyle(isHighlighted(row, col))} />
      </div>
    ));

    return (
      <div key={'row' + row}>
        {cells}
      </div>
    );
  };

  const gridStyle = {
    height,
    width,
    paddingLeft: '5px',
    backgroundColor: '#f0f0f0',
  } as any;

  const labelStyle = {
    width,
    color: '#808080',
    textAlign: 'center',
  } as any;


  const sizeLabel = size.rows + ' by ' + size.columns;

  return (
    <div style={gridStyle}>
      {rows.map((r: number) => mapRow(r))}
      <div style={labelStyle}>{sizeLabel}</div>
    </div>
  );
};
