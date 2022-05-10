import {
  CommandContext,
  CommandDescription,
} from 'components/editing/elements/commands/interfaces';
import { BlockToggle } from 'components/editing/toolbar/editorToolbar/Block';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { activeBlockType } from 'components/editing/toolbar/items';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel, safeToDOMNode } from 'components/editing/slateUtils';
import React from 'react';
import { Editor, Element } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';

interface Props {
  context: CommandContext;
  toolbarInsertDescs: CommandDescription[];
}
export const EditorToolbar = (props: Props) => {
  const editor = useSlate();

  return (
    <HoverContainer
      isOpen={isOpen}
      position="top"
      align="start"
      relativeTo={getHighestTopLevel(editor)
        .map((node) => safeToDOMNode(editor, node))
        .valueOr<any>(undefined)}
      content={
        <Toolbar context={props.context}>
          <BlockToggle descriptions={props.toolbarInsertDescs} />
          <BlockSettings type={activeBlockDesc.description(editor)} />
          {formatting}
          {insertMenu}
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
