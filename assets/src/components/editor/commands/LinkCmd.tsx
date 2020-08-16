import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms, Node, Range, Path, Editor, Text } from 'slate';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const selection = editor.selection;
    if (selection === null) return;

    // HELPERS

    // make sure we arent creating a link within a link
    const isLinkPresent = () => {

      // const parentNodeHasLink = () => {
      //   const parentType = Node.parent(editor, editor.selection?.anchor.path as Path)?.type;
      //   return parentType === 'a';
      // };

      const childNodesHaveLink = () => {
        return Node.fragment(editor, selection)
          .map(node => Array.from(Node.descendants(node))
            .reduce((acc, [node]) => node.type === 'a' ? true : acc, false))
          .some(bool => bool);
      };
      // parentNodeHasLink()
      return childNodesHaveLink();
    };

    const wrapLink = (editor: ReactEditor, range: Range, link: ContentModel.Hyperlink) => {
      Transforms.wrapNodes(editor, link, { split: true, at: range });
      Transforms.collapse(editor, { edge: 'end' });
    };

    // Wrap the selection with a HyperLink
    const addLink = () => {
      const offset1 = selection.anchor.offset < selection.focus.offset
        ? selection.anchor.offset : selection.focus.offset;
      const offset2 = offset1 === selection.anchor.offset
        ? selection.focus.offset : selection.anchor.offset;

      const [node] = Editor.node(editor,
        Editor.range(editor, selection.anchor, selection.focus));

      const href = Text.isText(node) ? node.text.slice(offset1, offset2) : 'Link URL';

      wrapLink(editor, selection, ContentModel.link(href));
    };

    const removeLinks = (editor: ReactEditor, range: Range) => {
      Transforms.unwrapNodes(editor, { at: range, match: node => node.type === 'a' });
      Transforms.collapse(editor, { edge: 'end' });
    };

    // LOGIC

    if (isLinkPresent()) {
      return removeLinks(editor, selection);
    }

    return addLink();
  },
  precondition: (editor: ReactEditor) => {
    return true;
  },
};


export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'insert_link',
  description: () => 'Link',
  command,
};
