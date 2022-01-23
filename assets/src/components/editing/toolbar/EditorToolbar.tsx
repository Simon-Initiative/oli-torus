import { codeLanguageDesc } from 'components/editing/elements/commands/BlockcodeCmd';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commands';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { listSettings } from 'components/editing/elements/commands/ListsCmd';
import { headingLevelDesc, headingTypeDescs } from 'components/editing/elements/commands/TitleCmd';
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
import { showTextEditorToolbar } from 'components/editing/toolbar/utils';
import { CodeLanguages } from 'data/content/model/other';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { useSlate } from 'slate-react';

interface Props {
  context: CommandContext;
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

  // ['paragraph', 'heading', 'list', 'quote', 'code'];

  // paragraph: none
  // heading: heading level
  // list: list types (with active icon), outdent, indent
  // quote: none
  // code: language

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
          {CodeLanguages.map((language, i) => (
            <DescriptiveButton
              key={i}
              description={createButtonCommandDesc({
                icon: '',
                description: language,
                active: (editor) => {
                  const [topLevel, at] = [...Editor.nodes(editor)][1];
                  if (Element.isElement(topLevel) && topLevel.type === 'code') {
                    return topLevel.language === language;
                  }
                  return false;
                },
                execute: (_ctx, editor) => {
                  const [, at] = [...Editor.nodes(editor)][1];
                  Transforms.setNodes(
                    editor,
                    { language },
                    { at, match: (e) => Element.isElement(e) && e.type === 'code' },
                  );
                  (window as any)?.hljs.highlightAll();
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
        {addDescs(null).map((desc, i) => (
          <DescriptiveButton key={i} description={desc} />
        ))}
      </DropdownButton>
    </Toolbar.Group>
  );

  /* {Filter for precondition} */
  return (
    <HoverContainer isOpen={showTextEditorToolbar}>
      <Toolbar context={props.context}>
        {blockToggling}
        {blockSettings?.()}
        {formatting}
        {insertMenu}
      </Toolbar>
    </HoverContainer>
  );
};
