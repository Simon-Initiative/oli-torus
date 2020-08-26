import { ReactEditor } from 'slate-react';
import { Editor, Range } from 'slate';
import { getHighestTopLevel, getNearestBlock, isActive, isTopLevel } from 'components/editor/utils';

export function shouldShowInsertionToolbar(editor: ReactEditor) {
  const { selection } = editor;
  const isSelectionCollapsed = selection
    && ReactEditor.isFocused(editor)
    && Range.isCollapsed(selection);

  const isInParagraph = Array.from(Editor.nodes(editor,
    { match: n => n.type === 'p' && (n.children as any)[0].text === '' })).length > 0;

  const isTopLevelOrInTable = isTopLevel(editor) || getHighestTopLevel(editor).caseOf({
    just: n => n.type === 'table',
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
    const editorNode = $(ReactEditor.toDOMNode(editor, editor));

    el.style.top = blockNode.position().top + 'px';
    el.style.left = editorNode.position().left - 5 + 'px';

    // There may be a better way to do this, but for now we're special-casing tables
    if (isActive(editor, ['table'])) {
      getHighestTopLevel(editor).lift((topLevel) => {
        const [match] = Editor.nodes(editor, { match: n => n.type === 'tr' });
        if (!match) {
          return;
        }
        const [tr] = match;
        el.style.top = blockNode.position().top +
          $(ReactEditor.toDOMNode(editor, topLevel)).position().top +
          $(ReactEditor.toDOMNode(editor, tr)).position().top + 'px';
      });
    }
  });
}
