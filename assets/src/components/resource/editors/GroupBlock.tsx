import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import {
  PurposeTypes,
  GroupContent,
  ResourceContent,
  isGroupWithPurpose,
  groupOrDescendantHasPurpose,
} from 'data/content/resource';
import { Purpose } from 'components/content/Purpose';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface GroupBlockProps {
  editMode: boolean;
  contentItem: GroupContent;
  parents: ResourceContent[];
  canRemove: boolean;
  contentBreaksExist: boolean;
  onEdit: (contentItem: GroupContent) => void;
  onRemove: () => void;
}
export const GroupBlock = ({
  editMode,
  contentItem,
  parents,
  canRemove,
  contentBreaksExist,
  children,
  onEdit,
  onRemove,
}: PropsWithChildren<GroupBlockProps>) => {
  const onEditPurpose = (purpose: string) => {
    onEdit(Object.assign(contentItem, { purpose }));
  };
  const onEditPaginationDisplay = (_e: any) => {
    const hidePaginationControls =
      contentItem.hidePaginationControls === undefined || !contentItem.hidePaginationControls
        ? true
        : false;
    onEdit(Object.assign(contentItem, { hidePaginationControls }));
  };

  // a purpose can only be set if no parents have a purpose or no children have purpose
  const canEditPurpose =
    parents.every((p) => !isGroupWithPurpose(p)) &&
    !contentItem.children.some((c) => groupOrDescendantHasPurpose(c));

  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.groupBlock, `purpose-${contentItem.purpose}`)}
    >
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        {contentBreaksExist ? (
          <div>
            <input
              type="checkbox"
              defaultChecked={
                contentItem.hidePaginationControls !== undefined &&
                contentItem.hidePaginationControls
              }
              onChange={(v: any) => onEditPaginationDisplay(v)}
            />
            <label className="ml-2 mr-4">Hide pagination controls</label>
          </div>
        ) : null}
        <Purpose
          purpose={contentItem.purpose}
          editMode={editMode}
          canEditPurpose={canEditPurpose}
          onEdit={onEditPurpose}
        />
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
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
