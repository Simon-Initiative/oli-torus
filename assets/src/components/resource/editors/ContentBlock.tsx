import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import {
  ActivityBankSelection,
  LearningObjectivesContent,
  StructuredContent,
} from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface ContentBlockProps {
  editMode: boolean;
  contentItem: StructuredContent | ActivityBankSelection | LearningObjectivesContent;
  canRemove: boolean;
  onRemove: (key: string) => void;
  headerActions?: React.ReactNode;
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
          {props.headerActions}
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
