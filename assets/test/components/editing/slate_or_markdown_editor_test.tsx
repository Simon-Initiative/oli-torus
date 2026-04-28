import React from 'react';
import { act, render } from '@testing-library/react';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Model } from 'data/content/model/elements/factories';

let markdownEditorProps: any;
let slateEditorProps: any;

jest.mock('components/editing/markdown_editor/MarkdownEditor', () => ({
  MarkdownEditor: (props: any) => {
    markdownEditorProps = props;
    return <div data-testid="markdown-editor" />;
  },
}));

jest.mock('components/editing/editor/Editor', () => ({
  Editor: (props: any) => {
    slateEditorProps = props;
    return <div data-testid="slate-editor" />;
  },
}));

jest.mock('components/editing/editor/SwitchToMarkdownModal', () => ({
  SwitchToMarkdownModal: () => null,
}));

jest.mock('components/editing/markdown_editor/SwitchToSlateModal', () => ({
  SwitchToSlateModal: () => null,
}));

describe('SlateOrMarkdownEditor', () => {
  beforeEach(() => {
    markdownEditorProps = undefined;
    slateEditorProps = undefined;
  });

  it('preserves markdown edits when switching back to the slate editor', () => {
    const initialContent = [Model.p('Initial paragraph')];
    const editedContent = [Model.p('Edited in markdown')];
    const onEdit = jest.fn();

    const { rerender } = render(
      <SlateOrMarkdownEditor
        allowBlockElements={true}
        className=""
        content={initialContent}
        editMode={true}
        editorType="markdown"
        onEdit={onEdit}
        projectSlug="project"
        toolbarInsertDescs={[]}
      />,
    );

    act(() => {
      markdownEditorProps.onEdit(editedContent, null, []);
    });

    rerender(
      <SlateOrMarkdownEditor
        allowBlockElements={true}
        className=""
        content={initialContent}
        editMode={true}
        editorType="slate"
        onEdit={onEdit}
        projectSlug="project"
        toolbarInsertDescs={[]}
      />,
    );

    expect(slateEditorProps.value).toBe(editedContent);
  });
});
