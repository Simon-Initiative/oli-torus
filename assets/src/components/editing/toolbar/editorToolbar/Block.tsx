import { codeLanguageDesc } from 'components/editing/elements/blockcode/codeblockActions';
import { CodeLanguages } from 'components/editing/elements/blockcode/codeLanguages';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import {
  headingLevelDesc,
  headingTypeDescs,
  toggleHeading,
} from 'components/editing/elements/heading/headingActions';
import { listSettings, toggleList } from 'components/editing/elements/list/listActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { DropdownButton } from 'components/editing/toolbar/buttons/DropdownButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { getHighestTopLevel } from 'components/editing/slateUtils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { useSlate } from 'slate-react';
import { toggleBlockquote } from 'components/editing/elements/blockquote/blockquoteActions';
import { toggleParagraph } from 'components/editing/elements/paragraph/paragraphActions';
import { activeBlockType } from 'components/editing/toolbar/toolbarUtils';

export const toggleTextTypes = [toggleParagraph, toggleHeading, toggleList, toggleBlockquote];

interface BlockToggleProps {}
export const BlockToggle = ({ descriptions }: BlockToggleProps) => {
  const editor = useSlate();
  const activeBlockDesc = activeBlockType(editor);

  if (descriptions.length === 0) return null;
  return (
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
};

interface BlockSettingProps {
  type: string;
}
export const BlockSettings = ({ type }: BlockSettingProps) => {
  const editor = useSlate();
  const activeBlockDesc = activeBlockType(editor);

  const Heading = () => (
    <DropdownButton description={headingLevelDesc(editor)}>
      {headingTypeDescs.map((desc, i) => (
        <CommandButton key={i} description={desc} />
      ))}
    </DropdownButton>
  );

  const component = {
    Heading,
    List: () => listSettings.map((desc, i) => <CommandButton key={i} description={desc} />),
    'Code (Block)': () => (
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
    ),
  }[type];

  return <Toolbar.Group>{React.createElement(type)}</Toolbar.Group>;
};
