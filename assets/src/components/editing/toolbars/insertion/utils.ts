import { ReactEditor } from 'slate-react';
import { Editor, Range } from 'slate';
import {
  getHighestTopLevel,
  getNearestBlock,
  isActive,
  isTopLevel,
} from 'components/editing/utils';

export function shouldShowInsertionToolbar(editor: ReactEditor) {
  const { selection } = editor;
  const isSelectionCollapsed =
    selection && ReactEditor.isFocused(editor) && Range.isCollapsed(selection);

  const isInParagraph =
    Array.from(
      Editor.nodes(editor, { match: (n) => n.type === 'p' && (n.children as any)[0].text === '' }),
    ).length > 0;

  const isTopLevelOrInTable =
    isTopLevel(editor) ||
    getHighestTopLevel(editor).caseOf({
      just: (n) => n.type === 'table',
      nothing: () => false,
    });

  const isInValidParents = isInParagraph && isTopLevelOrInTable;

  return isSelectionCollapsed && isInValidParents;
}

export function positionInsertion(el: HTMLElement, editor: ReactEditor) {
  getNearestBlock(editor).lift((block) => {
    el.style.position = 'absolute';
    el.style.opacity = '1';
    const blockNode = $(ReactEditor.toDOMNode(editor, block));

    el.style.top = blockNode.position().top + 'px';

    // There may be a better way to do this, but for now we're special-casing tables
    getHighestTopLevel(editor).lift((topLevel) => {
      const topLevelNode = $(ReactEditor.toDOMNode(editor, topLevel));
      el.style.left = topLevelNode.position().left - 10 + 'px';
      if (isActive(editor, ['table'])) {
        const [match] = Editor.nodes(editor, { match: (n) => n.type === 'tr' });
        if (!match) {
          return;
        }
        const [tr] = match;
        el.style.top =
          blockNode.position().top +
          topLevelNode.position().top +
          $(ReactEditor.toDOMNode(editor, tr)).position().top +
          2 +
          'px';
      }
    });
  });
}
