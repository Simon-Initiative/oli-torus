import * as React from 'react';
import * as Immutable from 'immutable';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ResourceContent, StructuredContent } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './PageBreak.modules.scss';

interface PageBreakProps {
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  contentItem: StructuredContent;
  onRemove: (key: string) => void;
}

export const PageBreak = (props: PageBreakProps) => {
  return (
    <div id={`resource-editor-${props.contentItem.id}`} className={classNames(styles.pageBreak)}>
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode}
          onClick={() => props.onRemove(props.contentItem.id)}
        />
      </div>
      <div className={styles.dashed}></div>
      <div className={styles.label}>PAGE BREAK</div>
      <div className={styles.dashed}></div>
    </div>
  );
};
