import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { StructuredContent, ActivityBankSelection } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface ContentBlockProps {
  editMode: boolean;
  contentItem: StructuredContent | ActivityBankSelection;
  canRemove: boolean;
  onRemove: (key: string) => void;
}

export const ContentBlock = (props: PropsWithChildren<ContentBlockProps>) => {
  return (
    <div
      id={`resource-editor-${props.contentItem.id}`}
      className={classNames(styles.contentBlock, 'content-block')}
    >
      <div className={styles.contentBlockHeader}>
        <div className="flex-grow-1"></div>
        <DeleteButton
          editMode={props.editMode && props.canRemove}
          onClick={() => props.onRemove(props.contentItem.id)}
        />
      </div>
      <div>{props.children}</div>
    </div>
  );
};
