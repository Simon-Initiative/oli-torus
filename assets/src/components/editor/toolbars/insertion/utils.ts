import { ReactEditor } from 'slate-react';
import { Editor, Range, Text } from 'slate';
import { getHighestTopLevel, getNearestBlock, isActive, isTopLevel, getNearestTopLevel } from 'components/editor/utils';

export function shouldShowInsertionToolbar(editor: ReactEditor) {
  const { selection } = editor;
  const isSelectionCollapsed = selection
    && ReactEditor.isFocused(editor)
    && Range.isCollapsed(selection);

  const isInParagraph = isActive(editor, ['p']);

  const isTopLevelOrInTable = isTopLevel(editor) || getHighestTopLevel(editor).caseOf({
    just: n => n.type === 'table',
    nothing: () => false,
  });

  const isInList = getNearestTopLevel(editor).caseOf({
    just: n => ['ul', 'ol'].indexOf(n.type as string) > -1,
    nothing: () => false,
  });

  // paragraph at top level or in table, or inside a list
  const isInValidParents = isInParagraph && isTopLevelOrInTable
    || isInList;
  // || isActive(editor, ['table'])
  // || isActive(editor, ['li']);

  return isSelectionCollapsed && isInValidParents;

  // True if the cursor is in a paragraph at the toplevel with no content
  const isCursorAtEmptyLine = () => {
    const nodes = Array.from(Editor.nodes(editor, { at: selection }));
    if (nodes.length !== 3) {
      return false;
    }
    const [[first], [second], [third]] = nodes;
    return Editor.isEditor(first) &&
      second.type === 'p' &&
      Text.isText(third) && third.text === '';
  };

  console.log('range collapsed', Range.isCollapsed(selection))

  // isCursorAtEmptyLine();
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
