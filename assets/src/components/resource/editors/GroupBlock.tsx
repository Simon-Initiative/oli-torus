import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { PurposeTypes, ResourceContent, GroupContent } from 'data/content/resource';
import * as Immutable from 'immutable';
import { Purpose } from 'components/content/Purpose';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface GroupBlockProps {
  editMode: boolean;
  contentItem: GroupContent;
  canRemove: boolean;
  onEdit: (contentItem: GroupContent) => void;
  onRemove: () => void;
}
export const GroupBlock = ({
  editMode,
  contentItem,
  canRemove,
  children,
  onEdit,
  onRemove,
}: PropsWithChildren<GroupBlockProps>) => {
  const onEditPurpose = (purpose: string) => {
    onEdit(Object.assign(contentItem, { purpose }));
  };

  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.groupBlock, `purpose-${contentItem.purpose}`)}
    >
      <div className={styles.actions}>
        <DeleteButton editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        <Purpose purpose={contentItem.purpose} editMode={editMode} onEdit={onEditPurpose} />
      </div>
      <MaybeDeliveryPurposeContainer contentItem={contentItem}>
        {children}
      </MaybeDeliveryPurposeContainer>
    </div>
  );
};

type PurposeContainerProps = {
  contentItem: GroupContent;
};

const MaybeDeliveryPurposeContainer = ({
  contentItem,
  children,
}: PropsWithChildren<PurposeContainerProps>) => {
  const purposeLabel = PurposeTypes.find((p) => p.value === contentItem.purpose)?.label;

  if (contentItem.purpose === 'none') {
    return <>{children}</>;
  }

  return (
    <div className={styles.purposeContainer}>
      <div className={`content-purpose ${contentItem.purpose}`}>
        <div className="content-purpose-label">{purposeLabel}</div>
        <div className="content-purpose-content">{children}</div>
      </div>
    </div>
  );
};
