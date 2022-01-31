import { CodeLanguages } from 'components/editing/nodes/blockcode/codeLanguages';
import { codeLanguageDesc } from 'components/editing/nodes/commands/BlockcodeCmd';
import { createButtonCommandDesc } from 'components/editing/nodes/commands/commands';
import { CommandContext, CommandDesc } from 'components/editing/nodes/commands/interfaces';
import { listSettings } from 'data/content/model/nodes/list/ListsCmd';
import { headingLevelDesc, headingTypeDescs } from 'components/editing/nodes/commands/TitleCmd';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import {
  activeBlockType,
  textTypeDescs,
  formatMenuCommands,
  formattingDropdownDesc,
  additionalFormattingOptions,
  addDesc,
  addDescs,
} from 'components/editing/toolbar/items';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel, safeToDOMNode } from 'components/editing/utils';
import { ActivityEditContext } from 'data/content/activity';
import { ResourceContent } from 'data/content/resource';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';
import { NewEditorToolbar } from 'components/editing/toolbar/NewEditorToolbar';

interface Props {
  context: CommandContext;
  toolbarInsertDescs: CommandDesc[];
}
export const EditorToolbar = (props: Props) => {
  const editor = useSlate();

  const activeBlockDesc = activeBlockType(editor);

  const blockToggling = (
    <Toolbar.Group>
      <DropdownButton description={activeBlockDesc}>
        {textTypeDescs
          .filter((type) => !type.active?.(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.Group>
  );

  const blockSettings = {
    Heading: () => (
      <Toolbar.Group>
        <DropdownButton description={headingLevelDesc(editor)}>
          {headingTypeDescs.map((desc, i) => (
            <CommandButton key={i} description={desc} />
          ))}
        </DropdownButton>
      </Toolbar.Group>
    ),
    List: () => (
      <Toolbar.Group>
        {listSettings.map((desc, i) => (
          <CommandButton key={i} description={desc} />
        ))}
      </Toolbar.Group>
    ),
    'Code (Block)': () => (
      <Toolbar.Group>
        <DropdownButton description={codeLanguageDesc(editor)}>
          {CodeLanguages.all().map(({ prettyName }, i) => (
            <DescriptiveButton
              key={i}
              description={createButtonCommandDesc({
                icon: '',
                description: prettyName,
                active: (editor) => {
                  const topLevel = getHighestTopLevel(editor).valueOr<any>(undefined);
                  return (
                    Element.isElement(topLevel) &&
                    topLevel.type === 'code' &&
                    topLevel.language === prettyName
                  );
                },
                execute: (_ctx, editor) => {
                  const [, at] = [...Editor.nodes(editor)][1];
                  Transforms.setNodes(
                    editor,
                    { language: prettyName },
                    { at, match: (e) => Element.isElement(e) && e.type === 'code' },
                  );
                },
              })}
            />
          ))}
        </DropdownButton>
      </Toolbar.Group>
    ),
  }[activeBlockDesc.description(editor)];

  const basicFormatting = formatMenuCommands.map((desc, i) => (
    <CommandButton key={i} description={desc} />
  ));

  const advancedFormatting = (
    <DropdownButton description={formattingDropdownDesc}>
      {additionalFormattingOptions.map((desc, i) => (
        <DescriptiveButton key={i} description={desc} />
      ))}
    </DropdownButton>
  );

  const formatting = (
    <Toolbar.Group>
      {basicFormatting}
      {advancedFormatting}
    </Toolbar.Group>
  );

  const insertMenu = (
    <Toolbar.Group>
      <DropdownButton description={addDesc}>
        {addDescs(null)
          .concat(props.toolbarInsertDescs)
          .filter((desc) => desc.command.precondition(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.Group>
  );

  /* {Filter for precondition} */
  return (
    <HoverContainer
      isOpen={isOpen}
      position="top"
      align="start"
      relativeTo={() =>
        getHighestTopLevel(editor).caseOf({
          just: (n) => safeToDOMNode(editor, n).valueOr(undefined as any),
          nothing: () => undefined,
        })
      }
      content={
        <Toolbar context={props.context}>
          <NewEditorToolbar />
        </Toolbar>
        // <Toolbar context={props.context}>
        //   {blockToggling}
        //   {blockSettings?.()}
        //   {formatting}
        //   {insertMenu}
        // </Toolbar>
      }
    />
  );
};

function isOpen(editor: Editor): boolean {
  const { selection } = editor;

  return (
    !!selection &&
    ReactEditor.isFocused(editor) &&
    [...Editor.nodes(editor)]
      .map((entry) => entry[0])
      .every((node) => !(Element.isElement(node) && editor.isVoid(node)))
  );
}
