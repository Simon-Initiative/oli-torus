import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ActivityBankSelection, StructuredContent } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface ContentBlockProps {
  editMode: boolean;
  contentItem: StructuredContent | ActivityBankSelection;
  canRemove: boolean;
  onRemove: (key: string) => void;
}

export const ContentBlock = React.forwardRef<HTMLDivElement, PropsWithChildren<ContentBlockProps>>(
  (props, ref) => {
    return (
      <div
        id={`resource-editor-${props.contentItem.id}`}
        ref={ref}
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
  },
);

ContentBlock.displayName = 'ContentBlock';
