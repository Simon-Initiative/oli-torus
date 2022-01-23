import { Editor, Element, Node, Text, Transforms } from 'slate';
import { CommandDesc, Command } from './interfaces';
import { elementsOfType, isMarkActive, textNodesInSelection } from '../../utils';
import { Mark } from 'data/content/model/text';
import { blockquote, code, ol, p, ul } from 'data/content/model/elements/factories';
import { ReactEditor } from 'slate-react';

interface CommandWrapperProps {
  icon: string;
  description: string;
  execute: Command['execute'];
  mark?: Mark;
  active?: CommandDesc['active'];
  precondition?: Command['precondition'];
}
export function toggleMark(editor: Editor, mark: Mark) {
  if (isMarkActive(editor, mark)) Editor.removeMark(editor, mark);
  else Editor.addMark(editor, mark, true);
}

export function createToggleFormatCommand(attrs: {
  icon: string;
  description: string;
  mark: Mark;
  precondition?: Command['precondition'];
}) {
  return createCommandDesc({
    ...attrs,
    execute: (context, editor) => toggleMark(editor, attrs.mark),
    active: (editor) => isMarkActive(editor, attrs.mark),
  });
}

export function createButtonCommandDesc(attrs: CommandWrapperProps) {
  return createCommandDesc(attrs);
}

function createCommandDesc({
  icon,
  description,
  execute,
  active,
  precondition,
}: CommandWrapperProps): CommandDesc {
  return {
    type: 'CommandDesc',
    icon: () => icon,
    description: () => description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: Editor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: (_editor) => true }),
    },
  };
}

const parentTextTypes = {
  p: true,
};

export const switchType = (editor: Editor, type: any) => {
  const [topLevel, at] = [...Editor.nodes(editor)][1];
  console.log('toplevel before', topLevel);
  if (!Element.isElement(topLevel)) return;

  const headings = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
  const lists = ['ul', 'ol'];
  const froms = ['p', ...headings, ...lists, 'blockquote', 'code'];

  const canonicalize = () => {
    // Convert element to a list of paragraphs
    switch (true) {
      case headings.includes(topLevel.type):
        return Transforms.setNodes(editor, { type: 'p' }, { at });
      case topLevel.type === 'p':
        return;
      case lists.includes(topLevel.type):
        Transforms.setNodes(
          editor,
          { type: 'p' },
          {
            at,
            mode: 'all',
            match: (e) => Element.isElement(e) && e.type === 'li',
          },
        );
        Transforms.unwrapNodes(editor, {
          at,
          mode: 'all',
          match: (e) => Element.isElement(e) && ['ul', 'ol'].includes(e.type),
        });
        return;
      case topLevel.type === 'blockquote':
        return Transforms.unwrapNodes(editor, { at });
      case topLevel.type === 'code':
        Transforms.setNodes(
          editor,
          { type: 'p' },
          { match: (e) => Element.isElement(e) && e.type === 'code_line' },
        );
        return Transforms.unwrapNodes(editor, { at });
      default:
        return;
    }
  };

  const convert = () => {
    console.log('node at that location', Editor.node(editor, at));
    if (!editor.selection) return;
    console.log('node at selection', [...Editor.nodes(editor, { at: editor.selection })]);
    switch (true) {
      case headings.includes(type):
        return Transforms.setNodes(editor, { type }, { at: editor.selection });
      case type === 'p':
        return;
      case lists.includes(type):
        Transforms.setNodes(
          editor,
          { type: 'li' },
          { match: (e) => Element.isElement(e) && e.type === 'p', mode: 'all' },
        );
        return Transforms.wrapNodes(editor, ul(), {
          match: (e) => Element.isElement(e) && e.type === 'li',
          mode: 'all',
        });
      case type === 'blockquote':
        console.log('wrapping nodes', [
          ...Editor.nodes(editor, {
            match: (e) => Element.isElement(e) && e.type === 'p',
            mode: 'all',
          }),
        ]);
        return Transforms.wrapNodes(editor, blockquote(), {
          match: (e) => Element.isElement(e) && e.type === 'p',
        });
      case type === 'code':
        Transforms.setNodes(
          editor,
          { type: 'code_line' },
          {
            match: (e) => Element.isElement(e) && e.type === 'p',
            mode: 'all',
          },
        );
        return Transforms.wrapNodes(editor, code(), {
          match: (e) => Element.isElement(e) && e.type === 'code_line',
          mode: 'all',
        });
      default:
        return;
    }
  };
  Editor.withoutNormalizing(editor, () => {
    canonicalize();
    convert();
  });
  // remember to get all toplevels in selection, not just first?
  // or maybe disable "transform" button if multiple nodes selected (prob this)

  // normalize: Paragraph[]

  // set to type

  //

  // para (p), heading (h1-h6), list (ul ol), blockquote, code

  // Get the correct toplevel node. Then only match/transform its children.

  // When toggling element types, "paragraph" is the canonical form.
  // This is just so we don't have to handle a cross product of transformations.

  // 1. Set paragraph-like elements to paragraph nodes.

  // const paragraphLike = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'code_line'];
  // console.log('nodes to set to Ps', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n) && paragraphLike.includes(n.type),
  //     at: path,
  //   }),
  // ]);
  // Transforms.setNodes(
  //   editor,
  //   { type: 'p' },
  //   {
  //     match: (n) => Element.isElement(n) && paragraphLike.includes(n.type),
  //     at: path,
  //     mode: 'all',
  //   },
  // );

  // console.log('nodes after p', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n),
  //     at: path,
  //   }),
  // ]);
  // // 2. Unwrap element structural containers
  // const wrappers = {
  //   ol: true,
  //   ul: true,
  //   blockquote: true,
  //   code: true,
  // };
  // console.log('nodes to unwrap', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n) && (wrappers as any)[n.type],
  //     at: path,
  //   }),
  // ]);
  // Transforms.unwrapNodes(editor, {
  //   match: (n) => Element.isElement(n) && (wrappers as any)[n.type],
  //   at: path,
  //   mode: 'all',
  // });

  // console.log('nodes after unwrap', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n),
  //     at: path,
  //   }),
  // ]);

  // // 3. Transform paragraphs to to the desired type.
  // Transforms.setNodes(
  //   editor,
  //   {
  //     type: (
  //       {
  //         h1: 'h1',
  //         h2: 'h2',
  //         h3: 'h3',
  //         h4: 'h4',
  //         h5: 'h5',
  //         h6: 'h6',
  //         ol: 'li',
  //         ul: 'li',
  //         blockquote: 'p',
  //         code: 'code_line',
  //       } as Record<string, any>
  //     )[type],
  //   },
  //   { match: (n) => Element.isElement(n) && n.type === 'p', mode: 'all', at: path },
  // );
  // console.log('nodes after setting', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n),
  //     at: path,
  //   }),
  // ]);
  // // 4. Wrap if necessary.
  // if (['ul', 'ol', 'blockquote', 'code'].includes(type)) {
  //   Transforms.wrapNodes(
  //     editor,
  //     (
  //       {
  //         ol: ol(),
  //         ul: ul(),
  //         blockquote: blockquote(),
  //         code: code(textNodesInSelection(editor)),
  //       } as Record<string, any>
  //     )[type],
  //     {
  //       at: path,
  //       match: (n) =>
  //         Element.isElement(n) && (n.type === 'p' || n.type === 'li' || n.type === 'code_line'),
  //     },
  //   );
  // }
  // console.log('nodes after wrapping', [
  //   ...Editor.nodes(editor, {
  //     match: (n) => Element.isElement(n),
  //     at: path,
  //   }),
  // ]);
  // });

  // FROM PARAGRAPH

  /* without normalizing, transform to paragraph and then to other type
    // para, => inputref/text (test in multi inputs)
    // heading => text
        xto para: heading -> para
        from para: para -> heading
    // list => ListItem | OrderedList | UnorderedList | Text
        xto para: li to para, unwrap ol/ul
        from para: paras to lis, wrap with UL
    // quote => paragraph
        xto para: unwrap quote
        from para: wrap with quote
    // code => code_line => text
        to para: code_line -> para, unwrap code
        from para: paras to codelines, wrap with code
  */
};
