import { codeLanguageDesc } from 'components/editing/elements/blockcode/codeblockActions';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  headingLevelDesc,
  headingTypeDescs,
} from 'components/editing/elements/heading/headingActions';
import {
  listSettingButtonGroups,
  orderedListStyleCommands,
  unorderedListStyleCommands,
} from 'components/editing/elements/list/listActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel, isActive } from 'components/editing/slateUtils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { useSlate } from 'slate-react';
import { activeBlockType } from 'components/editing/toolbar/toolbarUtils';
import { ListStyleToggle } from '../ListStyleToggle';

interface BlockSettingProps {}
export const BlockSettings = (_props: BlockSettingProps) => {
  const editor = useSlate();
  const type = activeBlockType(editor).description(editor);

  const component: Record<string, (() => JSX.Element) | undefined> = {
    Heading,
    List,
    'Code Block': CodeBlock,
  };

  if (component[type] !== undefined) {
    return <Toolbar.Group>{(component[type] as any)()}</Toolbar.Group>;
  }
  return null;
};

function List() {
  const editor = useSlate();
  const formatOptions = isActive(editor, ['ol'])
    ? orderedListStyleCommands
    : unorderedListStyleCommands;

  return (
    <>
      {listSettingButtonGroups.map((group, j) => (
        <Toolbar.ButtonGroup key={j}>
          {group.map((desc, i) => (
            <CommandButton key={i} description={desc} />
          ))}
        </Toolbar.ButtonGroup>
      ))}
      <Toolbar.ButtonGroup key="list-style">
        <ListStyleToggle listStyleOptions={formatOptions} />
      </Toolbar.ButtonGroup>
    </>
  );
}

function Heading() {
  const editor = useSlate();

  return (
    <Toolbar.ButtonGroup>
      <DropdownButton description={headingLevelDesc(editor)}>
        {headingTypeDescs.map((desc, i) => (
          <CommandButton key={i} description={desc} />
        ))}
      </DropdownButton>
    </Toolbar.ButtonGroup>
  );
}

function CodeBlock() {
  const editor = useSlate();

  const switchLanguage = (prettyName: string) =>
    createButtonCommandDesc({
      icon: <i className="fa-solid fa-laptop-code"></i>,
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
    });

  return (
    <Toolbar.ButtonGroup>
      <DropdownButton description={codeLanguageDesc(editor)}>
        {CodeLanguages.all().map(({ prettyName }, i) => (
          <DescriptiveButton key={i} description={switchLanguage(prettyName)} />
        ))}
      </DropdownButton>
    </Toolbar.ButtonGroup>
  );
}
