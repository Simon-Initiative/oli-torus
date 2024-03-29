import React, { FocusEventHandler, useCallback, useMemo, useState } from 'react';
import MDEditor, { ICommand, commands } from '@uiw/react-md-editor';
import { debounce } from 'lodash';
import { Descendant } from 'slate';
import { Icon } from 'components/misc/Icon';
import { TextDirection } from 'data/content/model/elements/types';
import { NormalizerContext } from '../editor/normalizers/normalizer';
import { CommandContext } from '../elements/commands/interfaces';
import { contentMarkdownDeserializer } from './content_markdown_deserializer';
import { serializeMarkdown } from './content_markdown_serializer';

interface MarkdownEditorProps {
  onEdit: (value: Descendant[], _editor: any, _operations: any[]) => void;
  onSwitchModes: () => void;
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
  textDirection?: TextDirection;
  onChangeTextDirection?: (textDirection: TextDirection) => void;
}

export const MarkdownEditor: React.FC<MarkdownEditorProps> = (props) => {
  const [value, setValue] = useState<string | undefined>(() =>
    contentMarkdownDeserializer(props.value),
  );
  const [lastSavedValue, setLastSavedValue] = useState<string | undefined>();

  const switchToSlateCommand: ICommand = {
    name: 'Switch to Slate',
    keyCommand: 'switch-to-slate',
    buttonProps: { 'aria-label': 'Switch to Slate' },
    icon: <Icon icon="newspaper" />,
    execute: () => {
      props.onSwitchModes();
      const content = serializeMarkdown(value || '');
      props.onEdit(content as Descendant[], null, []); // Trigger a save as well
    },
  };

  const textLabel = props.textDirection === 'ltr' ? 'Right to Left' : 'Left to Right';
  const textIcon = props.textDirection === 'rtl' ? 'right-long' : 'left-long';

  const changeTextDirectionCommand: ICommand = {
    name: `Change to ${textLabel} text direction`,
    keyCommand: 'switch-to-slate',
    buttonProps: { 'aria-label': `Change to ${textLabel} text direction` },
    icon: <Icon icon={textIcon} />,
    execute: () => {
      props.onChangeTextDirection &&
        props.onChangeTextDirection(props.textDirection === 'ltr' ? 'rtl' : 'ltr');
    },
  };

  const darkMode: boolean = useMemo(() => {
    return document.documentElement.classList.contains('dark');
  }, []);
  const { onEdit } = props;
  const modeClass = darkMode ? 'dark' : 'light';

  const saveChanges = useCallback(
    (newValue: string) => {
      if (newValue === lastSavedValue) {
        return;
      }
      setLastSavedValue(newValue);
      const content = serializeMarkdown(newValue);
      onEdit(content as Descendant[], null, []);
    },
    [lastSavedValue, onEdit],
  );

  const delayedSaveChanges = useMemo(
    () => debounce(saveChanges, 800, { maxWait: 5000 }),
    [saveChanges],
  );

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const onChange = useCallback(
    (newValue: string | undefined) => {
      setValue(newValue || '');
      delayedSaveChanges(newValue || '');
    },
    [delayedSaveChanges],
  );

  const onBlur = useCallback(() => {
    saveChanges(value || '');
  }, [value, saveChanges]);

  const extraCommands = [switchToSlateCommand, commands.fullscreen];
  if (props.onChangeTextDirection) {
    extraCommands.unshift(changeTextDirectionCommand);
  }

  return (
    <MDEditor
      value={value}
      className={props.className}
      onChange={onChange}
      height="auto"
      data-color-mode={modeClass}
      onBlur={onBlur}
      preview="edit"
      defaultTabEnable={true}
      style={props.style}
      direction={props.textDirection}
      commands={[
        commands.bold,
        commands.italic,
        commands.strikethrough,
        commands.title,
        commands.divider,
        commands.link,
        commands.quote,
        commands.code,
        commands.image,
        commands.divider,
        commands.unorderedListCommand,
        commands.orderedListCommand,
      ]}
      extraCommands={extraCommands}
    />
  );
};
