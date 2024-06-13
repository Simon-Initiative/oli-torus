import React, { PropsWithChildren } from 'react';
import { TextEditor } from 'components/TextEditor';
import { DeleteButton } from 'components/misc/DeleteButton';
import { ReportContent } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';
import styles from './ContentBlock.modules.scss';

interface ReportBlockProps {
  editMode: boolean;
  contentItem: ReportContent;
  canRemove: boolean;
  onEdit: (item: ReportContent) => void;
  onRemove: () => void;
}
export const ReportBlock = ({
  editMode,
  contentItem,
  canRemove,
  children,
  onEdit,
  onRemove,
}: PropsWithChildren<ReportBlockProps>) => {
  const onEditTitle = (title: string) => {
    onEdit(Object.assign(contentItem, { title }));
  };

  return (
    <div id={`resource-editor-${contentItem.id}`} className={classNames(styles.surveyBlock)}>
      <div className={styles.surveyBlockHeader}>
        <div className="self-center">
          <i className="fas fa-area-chart la-lg"></i>
        </div>
        <TextEditor
          label="Edit Report Title"
          onEdit={onEditTitle}
          model={valueOr(contentItem.title, 'Report')}
          showAffordances={true}
          allowEmptyContents={false}
          editMode={editMode}
        />
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      <div></div>
      <div>{children}</div>
    </div>
  );
};
