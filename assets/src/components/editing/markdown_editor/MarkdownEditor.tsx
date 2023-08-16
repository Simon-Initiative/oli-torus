import React, { FocusEventHandler, useMemo } from 'react';
import { Descendant } from 'slate';
import { NormalizerContext } from '../editor/normalizers/normalizer';
import { CommandContext } from '../elements/commands/interfaces';
import { contentMarkdownDeserializer } from './content_markdown_deserializer';

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
  const value = useMemo(() => contentMarkdownDeserializer(props.value), [props.value]);

  return (
    <div>
      <textarea value={value} cols={80} rows={40} />
    </div>
  );
};
