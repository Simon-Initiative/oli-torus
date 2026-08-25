import React, { PropsWithChildren } from 'react';
import { ActivityReference } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface ActivityBlockProps {
  editMode: boolean;
  canRemove: boolean;
  contentItem: ActivityReference;
  activityId: number;
  onRemove: (key: string) => void;
}

export const ActivityBlock = ({
  children,
  contentItem,
  activityId,
}: PropsWithChildren<ActivityBlockProps>) => {
  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.activityBlock, 'activity-block')}
    >
      <span id={`activity_${activityId}`} className="sr-only" aria-hidden="true" />
      <div>{children}</div>
    </div>
  );
};
