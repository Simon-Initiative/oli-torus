import React from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { Node, Transforms } from 'slate';
import { getRootOfText } from '../utils';

const parentTextTypes = {
  p: true,
  h1: true,
  h2: true,
  h3: true,
  h4: true,
  h5: true,
  h6: true,
};

const textOptions = [
  { value: 'p', text: 'Normal text' },
  { value: 'h1', text: 'Subtitle' },
  { value: 'h2', text: 'Heading 1' },
  { value: 'h3', text: 'Heading 2' },
  { value: 'h4', text: 'Heading 3' },
  { value: 'h5', text: 'Heading 4' },
  { value: 'h6', text: 'Heading 5' },
];

export const TextFormatter = () => {
  const editor = useSlate();
  const selected = getRootOfText(editor).caseOf({
    just: n => (parentTextTypes as any)[n.type as string] ? n.type : 'p',
    nothing: () => 'p',
  });

  const onChange = (e: any) => {
    getRootOfText(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type as string]) {
        const path = ReactEditor.findPath(editor, n);
        const type = e.target.value;
        Transforms.setNodes(editor, { type }, { at: path });
      }
    });

  };

  return (
    <select
      onChange={onChange}
      value={selected  as string}
      className="text-formatter custom-select custom-select-sm mr-3">
      {textOptions.map(o =>
        <option key={o.value} value={o.value}>{o.text}</option>)}
    </select>
  );
};
