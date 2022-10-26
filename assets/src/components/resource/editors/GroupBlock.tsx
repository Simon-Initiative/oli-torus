import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ResourceGroup, ResourceContent } from 'data/content/resource';
import styles from './ContentBlock.modules.scss';
import { PurposeGroupBlock } from './PurposeGroupEditor';

interface GroupBlockProps {
  editMode: boolean;
  contentItem: ResourceGroup;
  parents: ResourceContent[];
  canRemove: boolean;
  contentBreaksExist: boolean;
  onEdit: (contentItem: ResourceGroup) => void;
  onRemove: () => void;
}
export const GroupBlock = (props: PropsWithChildren<GroupBlockProps>) => {
  const { contentItem } = props;

  switch (contentItem.type) {
    case 'group':
      return <PurposeGroupBlock {...props} contentItem={contentItem} />;
    default:
      return <DefaultGroupBlock {...props} />;
  }
};

export const DefaultGroupBlock = (props: PropsWithChildren<GroupBlockProps>) => {
  const { editMode, contentItem, canRemove, children, onRemove } = props;

  return (
    <div id={`resource-editor-${contentItem.id}`} className={styles.groupBlock}>
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      {children}
    </div>
  );
};
