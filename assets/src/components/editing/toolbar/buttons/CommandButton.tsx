import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { ButtonContent } from 'components/editing/toolbar/buttons/shared';
import { useToolbar } from 'components/editing/toolbar/useToolbar';
import React from 'react';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';

interface Props {
  description: CommandDescription;
}
export const CommandButton = (props: Props) => {
  const editor = useSlate();
  const { context, closeSubmenus } = useToolbar();
  const { active, command } = props.description;

  return (
    <button
      className={classNames('editorToolbar__button', active?.(editor) && 'active')}
      onClick={(_e) => {
        command.execute(context, editor);
        closeSubmenus();
      }}
    >
      <ButtonContent description={props.description} />
    </button>
  );
};
