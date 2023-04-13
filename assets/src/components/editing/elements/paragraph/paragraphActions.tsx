import React from 'react';
import { toggleCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { switchType } from 'components/editing/elements/commands/toggleTextTypes';
import { toggleHeading } from 'components/editing/elements/heading/headingActions';
import { toggleUnorderedList } from 'components/editing/elements/list/listActions';
import { isActive } from 'components/editing/slateUtils';

export const toggleParagraph = createButtonCommandDesc({
  icon: <i className="fa-solid fa-paragraph"></i>,
  description: 'Paragraph',
  active: (editor) =>
    isActive(editor, 'p') &&
    [toggleHeading, toggleUnorderedList, toggleBlockquote, toggleCodeblock].every(
      (desc) => !desc.active?.(editor),
    ),
  execute: (_ctx, editor) => switchType(editor, 'p'),
});
