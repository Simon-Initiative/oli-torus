import {
  CommandContext,
  CommandDescription,
} from 'components/editing/elements/commands/interfaces';
import { BlockToggle } from 'components/editing/toolbar/editorToolbar/blocks/BlockToggle';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel, safeToDOMNode } from 'components/editing/slateUtils';
import React from 'react';
import { Editor, Element } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';
import { Inlines } from 'components/editing/toolbar/editorToolbar/Inlines';
import { BlockInsertMenu } from 'components/editing/toolbar/editorToolbar/blocks/BlockInsertMenu';
import { BlockSettings } from 'components/editing/toolbar/editorToolbar/blocks/BlockSettings';

interface Props {
  context: CommandContext;
  insertOptions: CommandDescription[];
  orientation: 'horizontal' | 'vertical';
}
export const EditorToolbar = (props: Props) => {
  const editor = useSlate();

  return (
    <HoverContainer
      isOpen={isOpen}
      position="left"
      align="start"
      relativeTo={() =>
        getHighestTopLevel(editor)
          .bind((node) => safeToDOMNode(editor, node))
          .valueOr<any>(undefined)
      }
      content={
        <Toolbar context={props.context} orientation={props.orientation}>
          <BlockToggle blockInsertOptions={props.insertOptions} />
          <BlockSettings />
          <Inlines />
          <BlockInsertMenu blockInsertOptions={props.insertOptions} />
        </Toolbar>
      }
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
