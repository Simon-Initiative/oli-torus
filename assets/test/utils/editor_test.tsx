/* eslint-disable @typescript-eslint/no-var-requires */
import { render } from '@testing-library/react';
import * as Utils from 'components/editing/utils';
import React from 'react';
import '@testing-library/jest-dom';
import { Editable, Slate, withReact } from 'slate-react';
import { createEditor, Descendant, Element } from 'slate';
import { InputRef, Mark, ModelElement, Paragraph } from 'data/content/model';
import { editorFor, markFor } from 'components/editing/editor/modelEditorDispatch';

const exampleContent = require('../writer/example_content.json');

export const testEditor = withReact(createEditor());
export const TestEditorComponent = () => {
  const [value, setValue] = React.useState<Descendant[]>(exampleContent.children);
  return (
    <Slate editor={testEditor} value={value} onChange={setValue}>
      <Editable
        renderElement={(props) =>
          editorFor(props.element as ModelElement, props, testEditor, { projectSlug: '' })
        }
        renderLeaf={({ attributes, children, leaf }) => (
          <span {...attributes}>
            {Object.keys(leaf).reduce(
              (m, k) => (k !== 'text' ? markFor(k as Mark, m) : m),
              children,
            )}
          </span>
        )}
        placeholder="Enter some text..."
      />
    </Slate>
  );
};

describe('slate editor utils', () => {
  it('can find elements of type', () => {
    render(<TestEditorComponent />);
    expect(Utils.elementsOfType<InputRef>(testEditor, 'input_ref')).toHaveLength(0);
    const paragraphs = Utils.elementsOfType<Paragraph>(testEditor, 'p');
    expect(paragraphs).toHaveLength(17);
    expect(paragraphs.every((p) => Element.isElement(p) && p.type === 'p')).toBeTruthy();
  });
});
