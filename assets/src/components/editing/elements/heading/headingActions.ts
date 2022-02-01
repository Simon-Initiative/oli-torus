import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { isActive } from 'components/editing/utils';

export const toggleHeading = createButtonCommandDesc({
  icon: 'title',
  description: 'Heading',
  active: (editor) => isActive(editor, ['h1', 'h2']),
  execute: (_ctx, editor) => switchType(editor, 'h2'),
});
