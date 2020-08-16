import { ReactEditor } from 'slate-react';
import { Transforms, Editor as SlateEditor } from 'slate';
import { CommandContext, Command, CommandDesc } from 'components/editor/commands/interfaces';
import { getNearestTopLevel } from 'components/editor/utils';

const toggleList = (editor: ReactEditor, listType: string) => {

  try {

    // The edits here result in intermediate states that normalization
    // would seek to correct.  So to allow this operation to succeed,
    // we instruct our editor instance to suspend normalization.
    (editor as any).suspendNormalization = true;

    const isActive = isActiveList(editor);

    Transforms.unwrapNodes(editor, {
      match: n => n.type === 'ul' || n.type === 'ol',
      split: true,
    });

    Transforms.setNodes(editor, {
      type: isActive ? 'p' : 'li',
    });

    if (!isActive) {
      const block = { type: listType, children: [] };
      Transforms.wrapNodes(editor, block);
    }
  } catch (error) {
    // tslint:disable-next-line
    console.error(error);

  } finally {
    // Whether the operation succeeded or failed, we restore
    // normalization
    (editor as any).suspendNormalization = false;
  }

};

const isActiveList = (editor: ReactEditor) => {
  const [match] = SlateEditor.nodes(editor, {
    match: n => n.type === 'ul' || n.type === 'ol',
  });

  return !!match;
};

const listCommandMaker = (listType: string) => {
  return {
    execute: (context: CommandContext, editor: ReactEditor) => {
      toggleList(editor, listType);
    },
    precondition: (editor: ReactEditor) => {
      return true;
    },
  };
};

const ulCommand: Command = listCommandMaker('ul');
const olCommand: Command = listCommandMaker('ol');

export const ulCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'format_list_bulleted',
  description: 'Unordered List',
  command: ulCommand,
  active: (editor: ReactEditor) => getNearestTopLevel(editor).caseOf({
    just: n => n.type === 'ul',
    nothing: () => false,
  }),
};

export const olCommandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'format_list_numbered',
  description: 'Ordered List',
  command: olCommand,
  active: (editor: ReactEditor) => getNearestTopLevel(editor).caseOf({
    just: n => n.type === 'ol',
    nothing: () => false,
  }),
};
