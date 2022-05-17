import { codeLanguageDesc } from 'components/editing/elements/blockcode/codeblockActions';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  headingLevelDesc,
  headingTypeDescs,
} from 'components/editing/elements/heading/headingActions';
import { listSettings } from 'components/editing/elements/list/listActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel } from 'components/editing/slateUtils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { useSlate } from 'slate-react';
import { activeBlockType } from 'components/editing/toolbar/toolbarUtils';

interface BlockSettingProps {}
export const BlockSettings = (_props: BlockSettingProps) => {
  const editor = useSlate();
  const type = activeBlockType(editor).description(editor);

  const component: Record<string, (() => JSX.Element) | undefined> = {
    Heading,
    List,
    'Code (Block)': CodeBlock,
  };

  return <Toolbar.Group>{component[type]}</Toolbar.Group>;
};

function List() {
  return (
    <>
      {listSettings.map((desc, i) => (
        <CommandButton key={i} description={desc} />
      ))}
    </>
  );
}

function Heading() {
  const editor = useSlate();

  return (
    <DropdownButton description={headingLevelDesc(editor)}>
      {headingTypeDescs.map((desc, i) => (
        <CommandButton key={i} description={desc} />
      ))}
    </DropdownButton>
  );
}

function CodeBlock() {
  const editor = useSlate();

  const switchLanguage = (prettyName: string) =>
    createButtonCommandDesc({
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
    });

  return (
    <DropdownButton description={codeLanguageDesc(editor)}>
      {CodeLanguages.all().map(({ prettyName }, i) => (
        <DescriptiveButton key={i} description={switchLanguage(prettyName)} />
      ))}
    </DropdownButton>
  );
}
