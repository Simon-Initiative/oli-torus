import React, { FocusEventHandler, useCallback, useMemo, useState } from 'react';
import '@uiw/react-markdown-preview/markdown.css';
import MDEditor from '@uiw/react-md-editor';
import '@uiw/react-md-editor/markdown-editor.css';
import { debounce } from 'lodash';
import { Descendant } from 'slate';
import { NormalizerContext } from '../editor/normalizers/normalizer';
import { CommandContext } from '../elements/commands/interfaces';
import { contentMarkdownDeserializer } from './content_markdown_deserializer';
import { serializeMarkdown } from './content_markdown_serializer';

interface MarkdownEditorProps {
  onEdit: (value: Descendant[], _editor: any, _operations: any[]) => void;
  // The content to display
  value: Descendant[];
  // Whether or not editing is allowed
  editMode: boolean;
  fixedToolbar?: boolean;
  commandContext: CommandContext;
  normalizerContext?: NormalizerContext;
  className?: string;
  style?: React.CSSProperties;
  placeholder?: string;
  onPaste?: React.ClipboardEventHandler<HTMLDivElement>;
  children?: React.ReactNode;
  onFocus?: FocusEventHandler | undefined;
  onBlur?: FocusEventHandler | undefined;
}

export const MarkdownEditor: React.FC<MarkdownEditorProps> = (props) => {
  const [value, setValue] = useState<string | undefined>(() =>
    contentMarkdownDeserializer(props.value),
  );

  const darkMode: boolean = useMemo(() => {
    return document.documentElement.classList.contains('dark');
  }, []);

  const modeClass = darkMode ? 'dark' : 'light';

  const saveChanges = useCallback(() => {
    const content = serializeMarkdown(value || '');
    console.info(JSON.stringify(content, null, 2));
  }, []);

  const delayedSave = useMemo(() => {
    return debounce(saveChanges, 5000);
  }, [saveChanges]);

  const onChange = useCallback((newValue: string | undefined) => {
    setValue(newValue || '');
    delayedSave();
  }, []);

  return (
    <div data-color-mode={modeClass}>
      <MDEditor
        value={value}
        onChange={onChange}
        height={600}
        data-color-mode={modeClass}
        onBlur={saveChanges}
        preview="edit"
      />
      {/* <textarea value={value} cols={80} rows={40} onChange={onChange} /> */}
      <button className="btn" onClick={saveChanges}>
        Save
      </button>
      ;
    </div>
  );
};
