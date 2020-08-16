import { ReactEditor } from 'slate-react';
import { Transforms, Editor as SlateEditor, Node, Path } from 'slate';
import * as ContentModel from 'data/content/model';
import guid from 'utils/guid';
import { Command, CommandDesc } from 'components/editor/commands/interfaces';
import { getNearestBlock } from 'components/editor/utils';
import { toggleMark } from 'components/editor/commands/commands';

const parentTextTypes = {
  p: true,
  code_line: true,
};

const isActiveCodeBlock = (editor: ReactEditor) => {
  /*
getNearestBlock(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type as string]) {
        const path = ReactEditor.findPath(editor, n);
        Transforms.setNodes(editor, { type: nextType }, { at: path });
      }
    });
  */

  return getNearestBlock(editor)
    .caseOf({
      just: n => n.type === 'code_line' || n.type === 'code',
      nothing: () => false,
    });
};

const selectedType = (editor: ReactEditor) => getNearestBlock(editor).caseOf({
  just: n => (parentTextTypes as any)[n.type as string] ? n.type as string : 'p',
  nothing: () => 'p',
});

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    // Returns a NodeEntry with the selected code Node if it exists
    const codeEntries = Array.from(SlateEditor.nodes(editor, {
      match: n => n.code === true,
    }));

    // Helpers
    const isActiveInlineCode = () => {
      return !!codeEntries[0];
    };

    // update children to the nodes that's inside the selection
    const addCodeBlock = () => {
      const Code = ContentModel.create<ContentModel.Code>(
        {
          type: 'code',
          language: 'python',
          showNumbers: false,
          startingLineNumber: 1,
          children: [
            // The NodeEntry has the actual code Node at its first index
            { type: 'code_line', children: codeEntries.map(([child]) => child) }], id: guid(),
        });
      // insert newline and add code there instead of wrapping the nodes in line
      Transforms.insertNodes(editor, Code);
    };

    function removeCodeBlock() {
      getNearestBlock(editor).lift((node) => {

        // console.log('node', node)



        // The code block is the root if multiple code lines are selected,
        // otherwise it's the parent of the code line
        const [codeBlock, codeBlockPath] = node.type === 'code'
          ? [node, ReactEditor.findPath(editor, node)]
          : SlateEditor.parent(editor, ReactEditor.findPath(editor, node));

        // console.log('codeBlock', codeBlock)


        //  Transforms.unsetNode to remove code marks does not work here because
        // of model constraints, so we manually delete the code property.
        const paragraphs = (codeBlock.children as Node[]).map(codeLine =>
          ContentModel.create<ContentModel.Paragraph>(
            {
              type: 'p', children: (codeLine.children as Node[])
                .map((child) => {
                  const node = Object.assign({}, child);
                  if (node.code) {
                    delete node.code;
                  }
                  return node;
                }) as Node[], id: guid(),
            }));
        const paths = [];
        let nextPath = Path.next(codeBlockPath);
        paragraphs.forEach((p) => {
          Transforms.insertNodes(editor, p, { at: nextPath });
          nextPath = Path.next(nextPath);
          paths.push(nextPath);
        });
        // Transforms.select(editor, )



        // console.log('code block path', codeBlockPath)
        // Transforms.insertFragment(editor, paragraphs, { at: Path.next(codeBlockPath) });
        Transforms.removeNodes(editor, { at: codeBlockPath });
        // Transforms.select(editor, Path.next(codeBlockPath));







        // console.log('codelines', codeLines)

        // console.log('path', codeBlockPath)
      });
      // Transforms.unsetNodes(editor, 'code', {
      //   at: Path.next(codeBlockPath),
      //   match: node => Text.isText(node),
      //   mode: 'lowest',
      // });
      // Transforms.removeNodes(editor, { at: codeBlockPath });
      // // Transforms.setNodes(editor, { type: 'p' },
      // //   { at: codeBlockPath, match: node => node.type === 'code_line' });
      // Transforms.insertNodes(editor,
      //   codeLines.map(line => Object.assign({}, line, { type: 'p' })), { at: codeBlockPath });


      // Transforms.liftNodes(editor, { at: codeBlockPath,})
      // Transforms.unwrapNodes(editor, { at: codeBlockPath, match:
      // node => node.type === 'code', mode: 'highest' });
      // Transforms.setNodes(editor, { type: 'p' },
      // { at: codeBlockPath, match: node => node.type === 'code_line' });
    }

    // Logic
    if (isActiveCodeBlock(editor)) {
      removeCodeBlock();
    }
    if (!isActiveInlineCode()) {
      return toggleMark(editor, 'code');
    }
    if (!isActiveCodeBlock(editor)) {
      return addCodeBlock();
    }
  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};

const description = (editor: ReactEditor) => {
  if (isActiveCodeBlock(editor)) {
    return 'Code-line';
  }
  return 'Code';
};

export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: () => 'code',
  description,
  command,
  active: marks => marks.indexOf('code') !== -1,
};
