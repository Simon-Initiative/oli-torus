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
import React from 'react';
import { Editor, Element } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';

interface Props {
  context: CommandContext;
  insertOptions: CommandDescription[];
  fixedToolbar?: boolean;
}

export const EditorToolbar = (props: Props) => {
  const editor = useSlate();
  const toolbar = (
    <Toolbar fixed={props.fixedToolbar} context={props.context}>
      <Inlines />
      <BlockToggle blockInsertOptions={props.insertOptions} />
      <BlockSettings />
      <BlockInsertMenu blockInsertOptions={props.insertOptions} />
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
