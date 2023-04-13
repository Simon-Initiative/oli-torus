import React from 'react';
import { useSlate } from 'slate-react';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { ButtonContent } from 'components/editing/toolbar/buttons/ButtonContent';
import { useToolbar } from 'components/editing/toolbar/hooks/useToolbar';
import { classNames } from 'utils/classNames';
import styles from '../Toolbar.modules.scss';

interface Props {
  description: CommandDescription;
}
export const CommandButton = (props: Props) => {
  const editor = useSlate();
  const { context, closeSubmenus } = useToolbar();
  const { active, command } = props.description;

  return (
    <button
      className={classNames(styles.toolbarButton, active?.(editor) && styles.active)}
      onMouseDown={(_e) => {
        command.execute(context, editor);
        closeSubmenus();
      }}
    >
      <ButtonContent description={props.description} />
    </button>
  );
};
