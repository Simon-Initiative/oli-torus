import React from 'react';
import { useSlate } from 'slate-react';
import { Tooltip } from 'components/common/Tooltip';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import styles from '../Toolbar.modules.scss';

interface Props {
  description: CommandDescription;
}
export const ButtonContent = (props: Props) => {
  const editor = useSlate();
  const { icon, description, tooltip } = props.description;

  const maybeIcon = icon(editor);

  return (
    <Tooltip title={tooltip || description(editor)}>
      <div className={styles.toolbarButtonContent}>
        {maybeIcon ? maybeIcon : <span className={styles.buttonText}>{description(editor)}</span>}
      </div>
    </Tooltip>
  );
};
