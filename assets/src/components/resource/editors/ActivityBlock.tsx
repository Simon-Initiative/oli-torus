import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ActivityReference } from 'data/content/resource';
import styles from './ContentBlock.modules.scss';
import { classNames } from 'utils/classNames';

interface ActivityBlockProps {
  editMode: boolean;
  canRemove: boolean;
  contentItem: ActivityReference;
  onRemove: (key: string) => void;
}

export const ActivityBlock = ({
  children,
  editMode,
  contentItem,
  canRemove,
  onRemove,
}: PropsWithChildren<ActivityBlockProps>) => {
  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.activityBlock, 'activity-block')}
    >
      <div className={styles.actions}>
        <DeleteButton editMode={editMode && canRemove} onClick={() => onRemove(contentItem.id)} />
      </div>
      <div className="p-2">{children}</div>
    </div>
  );
};
