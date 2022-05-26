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

export const ActivityBlock = ({ children, contentItem }: PropsWithChildren<ActivityBlockProps>) => {
  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.activityBlock, 'activity-block')}
    >
      <div>{children}</div>
    </div>
  );
};
