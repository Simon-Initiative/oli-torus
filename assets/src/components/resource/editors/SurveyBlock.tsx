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
  contentBreaksExist: boolean;
  onEdit: (item: SurveyContent) => void;
  onRemove: () => void;
}
export const SurveyBlock = ({
  editMode,
  contentItem,
  canRemove,
  children,
  contentBreaksExist,
  onEdit,
  onRemove,
}: PropsWithChildren<SurveyBlockProps>) => {
  const onEditTitle = (title: string) => {
    onEdit(Object.assign(contentItem, { title }));
  };
  const onEditPaginationDisplay = (_e: any) => {
    const hidePaginationControls =
      contentItem.hidePaginationControls === undefined || !contentItem.hidePaginationControls
        ? true
        : false;
    onEdit(Object.assign(contentItem, { hidePaginationControls }));
  };

  return (
    <div id={`resource-editor-${contentItem.id}`} className={classNames(styles.surveyBlock)}>
      <div className={styles.surveyBlockBorder}>
        <div className={styles.surveyBlockHeader}>
          <div className="align-self-center">
            <i className="las la-poll la-lg"></i>
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
          <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
        </div>
        <div>{children}</div>
      </div>
    </div>
  );
};
