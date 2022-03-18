import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { useToolbar } from 'components/editing/toolbar/useToolbar';
import React from 'react';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';

interface DescriptiveButtonProps {
  description: CommandDescription;
}
export const DescriptiveButton = (props: DescriptiveButtonProps) => {
  const editor = useSlate();
  const { context, closeSubmenus } = useToolbar();

  const onClick = React.useCallback(
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

  const classes = React.useMemo(
    () =>
      classNames('editorToolbar__button', 'editorToolbar__button--descriptive', active && 'active'),
    [active],
  );

  return (
    <button className={classes} onClick={onClick}>
      {icon && <span className="icon material-icons">{icon}</span>}
      {description}
    </button>
  );
};
