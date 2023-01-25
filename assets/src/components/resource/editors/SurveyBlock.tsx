import React, { PropsWithChildren } from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { SurveyContent } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';
import { TextEditor } from 'components/TextEditor';
import { valueOr } from 'utils/common';

interface SurveyBlockProps {
  editMode: boolean;
  contentItem: SurveyContent;
  canRemove: boolean;
  onEdit: (item: SurveyContent) => void;
  onRemove: () => void;
}
export const SurveyBlock = ({
  editMode,
  contentItem,
  canRemove,
  children,
  onEdit,
  onRemove,
}: PropsWithChildren<SurveyBlockProps>) => {
  const onEditTitle = (title: string) => {
    onEdit(Object.assign(contentItem, { title }));
  };

  return (
    <div id={`resource-editor-${contentItem.id}`} className={classNames(styles.surveyBlock)}>
      <div className={styles.surveyBlockHeader}>
        <div className="self-center">
          <i className="fas fa-poll la-lg"></i>
        </div>
        <TextEditor
          label="Edit Survey Title"
          onEdit={onEditTitle}
          model={valueOr(contentItem.title, 'Survey')}
          showAffordances={true}
          allowEmptyContents={false}
          editMode={editMode}
        />
        <div className="flex-grow-1"></div>
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      <div>{children}</div>
    </div>
  );
};
