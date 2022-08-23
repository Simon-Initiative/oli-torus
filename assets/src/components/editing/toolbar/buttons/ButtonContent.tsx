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

  return (
    <div className={styles.toolbarButtonContent}>
      {icon(editor) ? (
        <span className="material-icons">{icon(editor)}</span>
      ) : (
        <span className={styles.buttonText}>{description(editor)}</span>
      )}
    </div>
  );
};
