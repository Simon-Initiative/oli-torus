import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ResourceContent, StructuredContent } from 'data/content/resource';
import * as Immutable from 'immutable';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

interface ContentBlockProps {
  editMode: boolean;
  content: Immutable.List<ResourceContent>;
  contentItem: StructuredContent;
  index: number;
  onRemove: () => void;
}

export const ContentBlock = (props: PropsWithChildren<ContentBlockProps>) => {
  const id = `content-header-${props.index}`;

  return (
    <div
      id={id}
      className={classNames(
        styles.contentBlock,
        'content-block',
        `purpose-${props.contentItem.purpose}`,
      )}
    >
      <div className={styles.actions}>
        <DeleteButton editMode={props.content.size > 1} onClick={props.onRemove} />
      </div>
      <div id={props.contentItem.id}>{props.children}</div>
    </div>
  );
};
