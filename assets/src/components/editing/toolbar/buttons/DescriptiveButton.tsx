import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { useToolbar } from 'components/editing/toolbar/hooks/useToolbar';
import React from 'react';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';
import styles from '../Toolbar.modules.scss';

interface DescriptiveButtonProps {
  description: CommandDescription;
}
export const DescriptiveButton = (props: DescriptiveButtonProps) => {
  const editor = useSlate();
  const { context, closeSubmenus } = useToolbar();

  const onMouseDown = React.useCallback(
    (_e) => {
      props.description.command.execute(context, editor);
      closeSubmenus();
    },
    [props.description],
  );

  const icon = React.useMemo(() => props.description.icon(editor), [props.description]);

  const description = React.useMemo(
    () => props.description.description(editor),
    [props.description],
  );

  const active = React.useMemo(() => props.description.active?.(editor), [props.description]);

  return (
    <button
      className={classNames(styles.toolbarButton, styles.descriptive, active && styles.active)}
      onMouseDown={onMouseDown}
    >
      {icon && <span className={classNames(styles.icon)}>{icon}</span>}
      <span className={styles.description}>{description}</span>
    </button>
  );
};
