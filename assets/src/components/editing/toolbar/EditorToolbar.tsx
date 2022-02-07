import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { codeLanguageDesc } from 'components/editing/elements/blockcode/codeblockActions';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  CommandContext,
  CommandDescription,
} from 'components/editing/elements/commands/interfaces';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import {
  activeBlockType,
  formatMenuCommands,
  addItemDropdown,
  toggleTextTypes,
  formattingDropdownAction,
} from 'components/editing/toolbar/items';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel, safeToDOMNode } from 'components/editing/utils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor, useSlate } from 'slate-react';
import { additionalFormattingOptions } from 'components/editing/elements/marks/toggleMarkActions';
import { listSettings } from 'components/editing/elements/list/listActions';
import {
  headingLevelDesc,
  headingTypeDescs,
} from 'components/editing/elements/heading/headingActions';

interface Props {
  context: CommandContext;
  toolbarInsertDescs: CommandDescription[];
}
export const EditorToolbar = (props: Props) => {
  const editor = useSlate();

  const activeBlockDesc = activeBlockType(editor);

  const blockToggling = (
    <Toolbar.Group>
      <DropdownButton description={activeBlockDesc}>
        {toggleTextTypes
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
    <DropdownButton description={formattingDropdownAction}>
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
      <DropdownButton description={addItemDropdown}>
        {props.toolbarInsertDescs
          .filter((desc) => desc.command.precondition(editor))
          .map((desc, i) => (
            <DescriptiveButton key={i} description={desc} />
          ))}
      </DropdownButton>
    </Toolbar.Group>
  );

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
          {blockToggling}
          {blockSettings?.()}
          {formatting}
          {insertMenu}
        </Toolbar>
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
