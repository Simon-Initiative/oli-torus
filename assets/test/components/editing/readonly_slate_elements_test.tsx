import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { Descendant, createEditor } from 'slate';
import { Editable, Slate, withReact } from 'slate-react';
import { Editor } from 'components/editing/editor/Editor';
import { Toolbar } from 'components/editing/toolbar/Toolbar';

const mockFormulaClick = jest.fn();

jest.mock('components/editing/editor/modelEditorDispatch', () => ({
  editorFor: (element: any, props: any) => (
    <span {...props.attributes}>
      <span className={element.className} data-testid={element.testId} onClick={mockFormulaClick}>
        {props.children}
      </span>
    </span>
  ),
  markFor: (_mark: string, children: React.ReactNode) => children,
}));

const commandContext = { projectSlug: 'project' } as any;

const renderReadOnlySlate = (children: React.ReactNode) => {
  const editor = withReact(createEditor());
  const value: Descendant[] = [{ type: 'p', children: [{ text: '' }] } as any];

  return render(
    <Slate editor={editor} initialValue={value} onChange={jest.fn()}>
      <Editable
        readOnly={true}
        renderElement={(props) => <p {...props.attributes}>{props.children}</p>}
      />
      {children}
    </Slate>,
  );
};

describe('read-only slate editor elements', () => {
  beforeEach(() => {
    mockFormulaClick.mockClear();
  });

  it('does not render slate toolbars while the editor is read-only', () => {
    renderReadOnlySlate(
      <Toolbar context={commandContext}>
        <span data-testid="toolbar-action">Action</span>
      </Toolbar>,
    );

    expect(screen.queryByTestId('toolbar-action')).not.toBeInTheDocument();
  });

  it('suppresses authoring clicks inside a read-only editor', () => {
    render(
      <Editor
        commandContext={commandContext}
        editMode={false}
        onEdit={jest.fn()}
        toolbarInsertDescs={[]}
        value={[
          {
            type: 'formula',
            className: 'formula',
            testId: 'formula',
            children: [{ text: 'x^2' }],
          } as any,
        ]}
      />,
    );

    fireEvent.mouseDown(screen.getByTestId('formula'));
    fireEvent.click(screen.getByTestId('formula'));

    expect(mockFormulaClick).not.toHaveBeenCalled();
  });
});
