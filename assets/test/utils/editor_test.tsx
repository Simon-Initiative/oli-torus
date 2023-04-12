/* eslint-disable @typescript-eslint/no-var-requires */
import '@testing-library/jest-dom';
import { render } from '@testing-library/react';
import { editorFor, markFor } from 'components/editing/editor/modelEditorDispatch';
import * as Utils from 'components/editing/slateUtils';
import { InputRef, ModelElement, Paragraph } from 'data/content/model/elements/types';
import { Mark } from 'data/content/model/text';
import React from 'react';
import { Descendant, Element, createEditor } from 'slate';
import { Editable, Slate, withReact } from 'slate-react';

const exampleContent = require('../writer/example_content.json');

export const testEditor = withReact(createEditor());
export const TestEditorComponent = () => {
  const [value, setValue] = React.useState<Descendant[]>(exampleContent.children);

  // Mock for image element
  (window as any).ResizeObserver = class ResizeObserver {
    observe() {}
    unobserve() {}
    disconnect() {}
  };

  return (
    <Slate editor={testEditor} value={value} onChange={setValue}>
      <Editable
        renderElement={(props) =>
          editorFor(props.element as ModelElement, props, { projectSlug: '' })
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
