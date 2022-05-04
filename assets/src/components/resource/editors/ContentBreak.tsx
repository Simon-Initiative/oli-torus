import * as React from 'react';
import * as Immutable from 'immutable';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ResourceContent, StructuredContent } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBreak.modules.scss';

interface ContentBreakProps {
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  contentItem: StructuredContent;
  onRemove: (key: string) => void;
}

export const ContentBreak = (props: ContentBreakProps) => {
  return (
    <div id={`resource-editor-${props.contentItem.id}`} className={classNames(styles.contentBreak)}>
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode}
          onClick={() => props.onRemove(props.contentItem.id)}
        />
      </div>
      <div className={styles.dashed}></div>
      <div className={styles.label}>CONTENT BREAK</div>
      <div className={styles.dashed}></div>
    </div>
  );
};
