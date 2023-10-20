import React from 'react';
import { Editor, Element } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';
import {
  CommandContext,
  CommandDescription,
} from 'components/editing/elements/commands/interfaces';
import { getHighestTopLevel, safeToDOMNode } from 'components/editing/slateUtils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { Inlines } from 'components/editing/toolbar/editorToolbar/Inlines';
import { BlockInsertMenu } from 'components/editing/toolbar/editorToolbar/blocks/BlockInsertMenu';
import { BlockSettings } from 'components/editing/toolbar/editorToolbar/blocks/BlockSettings';
import { BlockToggle } from 'components/editing/toolbar/editorToolbar/blocks/BlockToggle';
import { TextDirection } from 'data/content/model/elements/types';
import { useDefaultTextDirection } from 'utils/useDefaultTextDirection';
import { EditorSettingsMenu } from './EditorSettingsMenu';

interface Props {
  context: CommandContext;
  insertOptions: CommandDescription[];
  fixedToolbar?: boolean;
  onSwitchToMarkdown?: () => void;
  textDirection?: TextDirection;
  onChangeTextDirection?: (textDirection: TextDirection) => void;
}

export const EditorToolbar = (props: Props) => {
  const editor = useSlate();
  const hasSettingsMenu = props.onSwitchToMarkdown || props.onChangeTextDirection;
  const [, setDefaultTextDir] = useDefaultTextDirection();

  const onTextDirectionChange = (textDirection: TextDirection) => {
    if (props.onChangeTextDirection) {
      props.onChangeTextDirection(textDirection);
    }
    setDefaultTextDir(textDirection);
  };

  const toolbar = (
    <Toolbar fixed={props.fixedToolbar} context={props.context}>
      <Inlines />
      <BlockToggle blockInsertOptions={props.insertOptions} />
      <BlockSettings />
      <BlockInsertMenu blockInsertOptions={props.insertOptions} />
      {hasSettingsMenu && (
        <EditorSettingsMenu
          onSwitchToMarkdown={props.onSwitchToMarkdown}
          textDirection={props.textDirection}
          onChangeTextDirection={onTextDirectionChange}
        />
      )}
    </Toolbar>
  );

  if (props.fixedToolbar) {
    return toolbar;
  }

  return (
    <HoverContainer
      isOpen={isOpen}
      position="top"
      align="start"
      reposition={true}
      relativeTo={() =>
        getHighestTopLevel(editor)
          .bind((node) => safeToDOMNode(editor, node))
          .valueOr<any>(undefined)
      }
      content={toolbar}
    />
  );
};

function isOpen(editor: Editor): boolean {
  const { selection } = editor;

  return (
    !!selection &&
    ReactEditor.isFocused(editor) &&
    [...Editor.nodes(editor)]
      .map((entry) => entry[0])
      .every((node) => !(Element.isElement(node) && editor.isVoid(node)))
  );
}
