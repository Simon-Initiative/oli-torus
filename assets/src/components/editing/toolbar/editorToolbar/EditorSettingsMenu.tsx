import React, { useMemo } from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { TextDirection } from 'data/content/model/elements/types';
import { CommandButton } from '../buttons/CommandButton';

interface Props {
  onSwitchToMarkdown?: () => void;
  textDirection?: TextDirection;
  onChangeTextDirection?: (textDirection: TextDirection) => void;
}

export const EditorSettingsMenu = ({
  onSwitchToMarkdown,
  textDirection,
  onChangeTextDirection,
}: Props) => {
  const markdownDesc = useMemo(
    () =>
      createButtonCommandDesc({
        icon: <i className="fa-brands fa-markdown"></i>,
        description: 'Switch to Markdown editor',
        execute: (_context, editor, src: string) => {
          onSwitchToMarkdown && onSwitchToMarkdown();
        },
      }),
    [onSwitchToMarkdown],
  );

  const textDirectionDesc = useMemo(
    () =>
      createButtonCommandDesc({
        icon: <i className={textDirection === 'rtl' ? 'fa fa-right-long' : 'fa fa-left-long'}></i>,
        description: `Change To ${
          textDirection === 'ltr' ? ' Right-to-Left ' : ' Left-to-Right '
        } text direction`,
        execute: (_context, editor, src: string) => {
          onChangeTextDirection && onChangeTextDirection(textDirection === 'ltr' ? 'rtl' : 'ltr');
        },
      }),
    [textDirection, onChangeTextDirection],
  );

  return (
    <Toolbar.Group>
      {onSwitchToMarkdown && <CommandButton description={markdownDesc} />}
      {onChangeTextDirection && <CommandButton description={textDirectionDesc} />}
    </Toolbar.Group>
  );
};
