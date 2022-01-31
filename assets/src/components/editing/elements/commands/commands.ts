import { Editor, Element, Transforms } from 'slate';
import { CommandDesc, Command } from './interfaces';
import { isMarkActive } from '../../utils';
import { Mark } from 'data/content/model/text';
import { Model } from 'data/content/model/elements/factories';

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

export const switchType = (editor: Editor, type: any) => {
  const [topLevel, at] = [...Editor.nodes(editor)][1];
  if (!Element.isElement(topLevel)) return;

  const headings = ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
  const lists = ['ul', 'ol'];
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
      default:
        return;
    }
  };

  const convert = () => {
    if (!editor.selection) return;
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
        return Transforms.wrapNodes(editor, Model.ul(), {
          match: (e) => Element.isElement(e) && e.type === 'li',
          mode: 'all',
        });
      case type === 'blockquote':
        return Transforms.wrapNodes(editor, Model.blockquote(), {
          match: (e) => Element.isElement(e) && e.type === 'p',
        });
      default:
        return;
    }
  };
  Editor.withoutNormalizing(editor, () => {
    canonicalize();
    convert();
  });
};
