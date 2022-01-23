import React from 'react';
import { updateModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';
import { useSlate } from 'slate-react';

export type CodeProps = EditorProps<ContentModel.Code>;

export const CodeEditor = (props: CodeProps) => {
  const editor = useSlate();

  const onEdit = (updated: Partial<ContentModel.Code>) =>
    updateModel<ContentModel.Code>(editor, props.model, updated);

  return (
    <div {...props.attributes} className="code-editor">
      <pre style={{ fontFamily: 'Menlo, Monaco, Courier New, monospace' }}>
        <code
          className={`language-${props.model.language.trim().split(' ').join('').toLowerCase()}`}
        >
          {props.children}
        </code>
      </pre>
      <CaptionEditor onEdit={(caption) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
