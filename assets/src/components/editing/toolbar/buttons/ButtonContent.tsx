import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import React from 'react';
import { useSlate } from 'slate-react';
import styles from '../Toolbar.modules.scss';

interface Props {
  description: CommandDescription;
}
export const ButtonContent = (props: Props) => {
  const editor = useSlate();
  const { icon, description } = props.description;

  const maybeIcon = icon(editor);

  return (
    <div className={styles.toolbarButtonContent}>
      {maybeIcon ? maybeIcon : <span className={styles.buttonText}>{description(editor)}</span>}
    </div>
  );
};
