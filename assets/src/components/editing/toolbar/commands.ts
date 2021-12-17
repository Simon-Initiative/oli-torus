import { Editor } from 'slate';
import { ToolbarButtonDesc, ButtonCommand } from './interfaces';
import { isMarkActive } from '../utils';
import { Mark } from 'data/content/model/text';

export function toggleMark(editor: Editor, mark: Mark) {
  if (isMarkActive(editor, mark)) return Editor.removeMark(editor, mark);
  return Editor.addMark(editor, mark, true);
}

export function formatButtonDesc(attrs: {
  icon: ToolbarButtonDesc['icon'];
  description: ToolbarButtonDesc['description'];
  mark: Mark;
  precondition?: ButtonCommand['precondition'];
}) {
  return toolbarButtonDesc({
    ...attrs,
    execute: (context, editor) => toggleMark(editor, attrs.mark),
    active: (editor) => isMarkActive(editor, attrs.mark),
  });
}

interface ToolbarButtonDescProps {
  icon: ToolbarButtonDesc['icon'];
  description: ToolbarButtonDesc['description'];
  active?: ToolbarButtonDesc['active'];
  renderMode?: ToolbarButtonDesc['renderMode'];

  execute: ButtonCommand['execute'];
  precondition?: ButtonCommand['precondition'];
}
export const toolbarButtonDesc = ({
  icon,
  description,
  active,
  execute,
  precondition,
  renderMode,
}: ToolbarButtonDescProps): ToolbarButtonDesc => {
  return {
    type: 'ToolbarButtonDesc',
    renderMode: renderMode || 'Simple',
    icon,
    description,
    ...(active ? { active } : {}),
    command: {
      execute: (context, editor: Editor) => execute(context, editor),
      ...(precondition ? { precondition } : { precondition: (_editor) => true }),
    },
  };
};
