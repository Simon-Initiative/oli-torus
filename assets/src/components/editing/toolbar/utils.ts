import { ReactEditor } from 'slate-react';
import { Editor, Element, Node, Path, Range, Text } from 'slate';
import {
  getHighestTopLevel,
  getNearestBlock,
  isActive,
  isTopLevel,
} from 'components/editing/utils';
import { ToolbarItem } from 'components/editing/elements/commands/interfaces';

export function showTextEditorToolbar(editor: Editor): boolean {
  const { selection } = editor;

  return (
    !!selection &&
    ReactEditor.isFocused(editor) &&
    [...Editor.nodes(editor)]
      .map((entry) => entry[0])
      .every((node) => (Element.isElement(node) ? !editor.isVoid(node) : true))
  );
}

export function inEmptyLine(editor: Editor) {
  const { selection } = editor;
  if (!selection) return false;
  const selectionCollapsed = ReactEditor.isFocused(editor) && Range.isCollapsed(selection);

  console.log('focused', ReactEditor.isFocused(editor), 'collapsed', Range.isCollapsed(selection));

  const inParagraph =
    [
      ...Editor.nodes(editor, {
        match: (n) => {
          if (!Element.isElement(n) || n.type !== 'p') return false;
          return Text.isText(n.children[0]) && n.children[0].text === '';
        },
      }),
    ].length > 0;

  const inTopLevelOrTable =
    isTopLevel(editor) ||
    getHighestTopLevel(editor).caseOf({
      just: (n) => Element.isElement(n) && n.type === 'table',
      nothing: () => false,
    });

  const parentIsValid = inParagraph && inTopLevelOrTable;

  return selectionCollapsed && parentIsValid;
}

export function positionInsertion(el: HTMLElement, editor: Editor) {
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
        const [match] = Editor.nodes(editor, {
          match: (n) => Element.isElement(n) && n.type === 'tr',
        });
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

type ToolbarContentType = 'all' | 'small';
// Can be extended to provide different insertion toolbar options based on resource type
export function getToolbarForContentType(
  onRequestMedia: any,
  type = 'all' as ToolbarContentType,
): ToolbarItem[] {
  return [];
  // if (type === 'small') {
  //   return [
  //     codeCmd,
  //     imageCommandBuilder(onRequestMedia),
  //     ytCmdDesc,
  //     audioCommandBuilder(onRequestMedia),
  //   ];
  // }
  // return [
  //   tableCommandDesc,
  //   codeCmd,
  //   {
  //     type: 'GroupDivider',
  //   },
  //   imageCommandBuilder(onRequestMedia),
  //   ytCmdDesc,
  //   audioCommandBuilder(onRequestMedia),
  //   webpageCmdDesc,
  // ];
}
